# AMD GPU driver configuration (RDNA3 / RX 7000 series)
# The amdgpu kernel driver is built-in, Mesa provides Vulkan (RADV) and OpenGL.
{
  lib,
  config,
  ...
}: {
  # Enable graphics stack (Mesa Vulkan/OpenGL drivers)
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # needed for Steam/Wine 32-bit apps
  };

  # Load amdgpu driver in initramfs for early KMS
  hardware.amdgpu.initrd.enable = true;

  # Optional: Enable OpenCL compute support
  # hardware.amdgpu.opencl.enable = true;

  # Optional: GPU overclocking/undervolting GUI
  # services.lact.enable = true;
}
