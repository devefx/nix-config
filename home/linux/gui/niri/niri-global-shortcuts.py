#!/usr/bin/env python3

import asyncio
import re
import time

from dbus_next import Variant
from dbus_next.aio import MessageBus
from dbus_next.service import (
    PropertyAccess,
    ServiceInterface,
    dbus_property,
    method,
    signal,
)


MODIFIER_NAMES = {
    "alt": "Alt",
    "control": "Ctrl",
    "ctrl": "Ctrl",
    "logo": "Super",
    "meta": "Super",
    "shift": "Shift",
    "super": "Super",
}


def normalize_accelerator(accelerator):
    tokens = [token for token in re.split(r"[+<>]+", accelerator) if token]
    if not tokens:
        return accelerator

    modifiers = []
    key = accelerator
    for token in tokens:
        modifier = MODIFIER_NAMES.get(token.lower())
        if modifier is not None:
            modifiers.append(modifier)
        else:
            key = token[0].upper() + token[1:]

    return "".join(modifiers) + key


class Shell(ServiceInterface):
    def __init__(self):
        super().__init__("org.gnome.Shell")
        self._next_action = 1
        self._actions = {}

    @method()
    def GrabAccelerators(self, accelerators: "a(suu)") -> "au":
        action_ids = []
        for accelerator, _mode, _flags in accelerators:
            action_id = self._next_action
            self._next_action += 1
            self._actions[action_id] = normalize_accelerator(accelerator)
            action_ids.append(action_id)
        return action_ids

    @method()
    def UngrabAccelerator(self, action: "u") -> "b":
        return self._actions.pop(action, None) is not None

    @method()
    def UngrabAccelerators(self, actions: "au") -> "b":
        for action in actions:
            self._actions.pop(action, None)
        return True

    @signal()
    def AcceleratorActivated(self, action: "u", parameters: "a{sv}") -> "ua{sv}":
        return [action, parameters]

    def activate(self, accelerator):
        accelerator = normalize_accelerator(accelerator)
        action_ids = [
            action_id
            for action_id, registered in self._actions.items()
            if registered == accelerator
        ]
        if not action_ids:
            return False

        parameters = {"timestamp": Variant("u", int(time.time()) & 0xFFFFFFFF)}
        for action_id in action_ids:
            self.AcceleratorActivated(action_id, parameters)
        return True


class ShellIntrospect(ServiceInterface):
    def __init__(self):
        super().__init__("org.gnome.Shell.Introspect")

    @method()
    def GetRunningApplications(self) -> "a{sa{sv}}":
        return {}

    @method()
    def GetWindows(self) -> "a{ta{sv}}":
        return {}

    @dbus_property(access=PropertyAccess.READ)
    def version(self) -> "u":
        return 1

    @signal()
    def RunningApplicationsChanged(self):
        return None

    @signal()
    def WindowsChanged(self):
        return None


class GlobalShortcutsProvider(ServiceInterface):
    def __init__(self):
        super().__init__("org.gnome.Settings.GlobalShortcutsProvider")

    @method()
    def BindShortcuts(
        self,
        app_id: "s",
        parent_window: "s",
        shortcuts: "a(sa{sv})",
    ) -> "a(sa{sv})":
        results = []
        for shortcut_id, options in shortcuts:
            result = {}
            description = options.get("description")
            trigger = options.get("preferred_trigger")

            if description is not None:
                result["description"] = description
            if trigger is not None:
                result["shortcuts"] = Variant("as", [trigger.value])

            results.append([shortcut_id, result])

        return results


class Activation(ServiceInterface):
    def __init__(self, shell):
        super().__init__("org.nixos.NiriGlobalShortcuts")
        self._shell = shell

    @method()
    def Activate(self, accelerator: "s") -> "b":
        return self._shell.activate(accelerator)


async def main():
    bus = await MessageBus().connect()
    shell = Shell()

    bus.export("/org/gnome/Shell", shell)
    bus.export("/org/gnome/Shell/Introspect", ShellIntrospect())
    bus.export(
        "/org/gnome/Settings/GlobalShortcutsProvider",
        GlobalShortcutsProvider(),
    )
    bus.export("/org/nixos/NiriGlobalShortcuts", Activation(shell))

    await bus.request_name("org.gnome.Shell")
    await bus.request_name("org.gnome.Settings.GlobalShortcutsProvider")
    await bus.wait_for_disconnect()


if __name__ == "__main__":
    asyncio.run(main())
