{
  # Timezone paired with locale — keep together since they're the same
  # "where am I" concern.
  time.timeZone = "Asia/Shanghai";

  # Interface language stays English — error messages and man pages are
  # easier to search that way. Data formatting (dates, numbers, money)
  # switches to zh_CN via the LC_* overrides below.
  i18n.defaultLocale = "en_US.UTF-8";

  # Only generate the two locales we actually use (full `all` bundle is
  # ~200MB).
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];

  # English UI + Chinese data formats (dates, numbers, currency, ...).
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };
}
