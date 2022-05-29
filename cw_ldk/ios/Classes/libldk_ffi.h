#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * A Dart_CObject is used for representing Dart objects as native C
 * data outside the Dart heap. These objects are totally detached from
 * the Dart heap. Only a subset of the Dart objects have a
 * representation as a Dart_CObject.
 *
 * The string encoding in the 'value.as_string' is UTF-8.
 *
 * All the different types from dart:typed_data are exposed as type
 * kTypedData. The specific type from dart:typed_data is in the type
 * field of the as_typed_data structure. The length in the
 * as_typed_data structure is always in bytes.
 *
 * The data for kTypedData is copied on message send and ownership remains with
 * the caller. The ownership of data for kExternalTyped is passed to the VM on
 * message send and returned when the VM invokes the
 * Dart_WeakPersistentHandleFinalizer callback; a non-NULL callback must be
 * provided.
 */
typedef struct DartCObject DartCObject;
enum DartCObjectType
#ifdef __cplusplus
    : int32_t
#endif // __cplusplus
{
  DartNull = 0,
  DartBool = 1,
  DartInt32 = 2,
  DartInt64 = 3,
  DartDouble = 4,
  DartString = 5,
  DartArray = 6,
  DartTypedData = 7,
  DartExternalTypedData = 8,
  DartSendPort = 9,
  DartCapability = 10,
  DartUnsupported = 11,
  DartNumberOfTypes = 12,
};
#ifndef __cplusplus
typedef int32_t DartCObjectType;
#endif // __cplusplus

enum DartTypedDataType
#ifdef __cplusplus
    : int32_t
#endif // __cplusplus
{
  kByteData = 0,
  kInt8 = 1,
  kUint8 = 2,
  kUint8Clamped = 3,
  kInt16 = 4,
  kUint16 = 5,
  kInt32 = 6,
  kUint32 = 7,
  kInt64 = 8,
  kUint64 = 9,
  kFloat32 = 10,
  kFloat64 = 11,
  kFloat32x4 = 12,
  kInvalid = 13,
};
#ifndef __cplusplus
typedef int32_t DartTypedDataType;
#endif // __cplusplus

typedef void *RuntimePtr;

/**
 * A port is used to send or receive inter-isolate messages
 */
typedef int64_t DartPort;

typedef struct DartNativeSendPort
{
  DartPort id;
  DartPort origin_id;
} DartNativeSendPort;

typedef struct DartNativeCapability
{
  int64_t id;
} DartNativeCapability;

typedef struct DartNativeArray
{
  intptr_t length;
  DartCObject **values;
} DartNativeArray;

typedef struct DartNativeTypedData
{
  DartTypedDataType type_;
  intptr_t length;
  uint8_t *values;
} DartNativeTypedData;

typedef struct _DartWeakPersistentHandle
{
  uint8_t _unused[0];
} _DartWeakPersistentHandle;

typedef _DartWeakPersistentHandle *DartWeakPersistentHandle;

typedef void (*DartWeakPersistentHandleFinalizer)(void *isolate_callback_data, DartWeakPersistentHandle handle, void *peer);

typedef struct DartNativeExternalTypedData
{
  DartTypedDataType type_;
  intptr_t length;
  uint8_t *data;
  void *peer;
  DartWeakPersistentHandleFinalizer callback;
} DartNativeExternalTypedData;

typedef union DartCObjectValue {
  bool as_bool;
  int32_t as_int32;
  int64_t as_int64;
  double as_double;
  char *as_string;
  DartNativeSendPort as_send_port;
  DartNativeCapability as_capability;
  DartNativeArray as_array;
  DartNativeTypedData as_typed_data;
  DartNativeExternalTypedData as_external_typed_data;
  uint64_t _bindgen_union_align[5];
} DartCObjectValue;

typedef struct DartCObject
{
  DartCObjectType type_;
  DartCObjectValue value;
} DartCObject;

/**
 *  Posts a message on some port. The message will contain the
 *  Dart_CObject object graph rooted in 'message'.
 *
 *  While the message is being sent the state of the graph of
 *  Dart_CObject structures rooted in 'message' should not be accessed,
 *  as the message generation will make temporary modifications to the
 *  data. When the message has been sent the graph will be fully
 *  restored.
 *
 *  port_id The destination port.
 *  message The message to send.
 *
 *  return true if the message was posted.
 */
typedef bool (*DartPostCObjectFnPtr)(DartPort port_id, DartCObject *message);

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

/**
 * Destroy the Tokio Runtime, and return 1 if everything is okay
 */
int32_t destroy_runtime(RuntimePtr runtime);

//// begin insert 

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

//// end insert
/**
 * Setup a new Tokio Runtime and return a pointer to it so it could be used later to run tasks
 */
RuntimePtr setup_runtime(DartPostCObjectFnPtr post_cobject);

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus
