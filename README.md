# libtool wrapper

Small wrapper that tries to select the right tool version depending on
a number of factors:
* Which version is requested via WANT_LIBTOOL setting
* Which version was used to generate the project files
* If all else fails, try the latest version available
