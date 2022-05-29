#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

int32_t last_error_length(void);

int32_t error_message_utf8(char *buf, int32_t length);

/**
 * ffi interface for starting the LDK.
 */
void start_ldk(const char *rpc_info,
               const char *ldk_storage_path,
               uint16_t port,
               const char *network,
               const char *node_name,
               const char *address,
               const char *mnemonic_key_phrase,
               void (*func)(char*));

int32_t send_message(const char *msg, int64_t isolate_port);

/**
 * dummy function to call in ios to avoid tree shacking.
 */
void hello_world(void);

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus
