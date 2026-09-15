{
  # Timezone paired with locale — keep together since they're the same
  # "where am I" concern.
  time.timeZone = "Asia/Shanghai";

  # Chinese UI for desktop applications. Kitty explicitly overrides message
  # locale back to English for terminal output and man pages.
  i18n.defaultLocale = "zh_CN.UTF-8";

  # Only generate the two locales we actually use (full `all` bundle is
  # ~200MB).
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];
}
