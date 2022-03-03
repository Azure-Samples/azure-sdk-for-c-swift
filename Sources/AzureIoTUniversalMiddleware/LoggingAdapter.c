#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include "AzureIoT.h"

#define UNIX_EPOCH_START_YEAR 1900

static void console_logging_function(log_level_t log_level, char const* const format, ...)
{
  char message[256];
  va_list ap;
  va_start(ap, format);
  int message_length = vsnprintf(message, 256, format, ap);
  va_end(ap);

  if (message_length < 0)
  {
    printf("Failed encoding log message (!)");
  }
  else
  {
    printf("%s\r\n", message);
  }
}

void set_console_logging_function()
{
    set_logging_function(console_logging_function);
}

