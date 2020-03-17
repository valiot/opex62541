#include <open62541.h>

#include <signal.h>
#include <stdlib.h>

static volatile UA_Boolean running = true;
UA_Double temperature = 20.0;

static void stopHandler(int sig) {
    UA_LOG_INFO(UA_Log_Stdout, UA_LOGCATEGORY_USERLAND, "received ctrl-c");
    running = false;
}

static void
beforeReadTemperature(UA_Server *server,
               const UA_NodeId *sessionId, void *sessionContext,
               const UA_NodeId *nodeid, void *nodeContext,
               const UA_NumericRange *range, const UA_DataValue *data) {

    temperature = 1.0*(rand() % 100)/100 - 0.5;
    UA_Variant value;
    UA_Variant_setScalar(&value, &temperature, &UA_TYPES[UA_TYPES_DOUBLE]);
    UA_Server_writeValue(server,  UA_NODEID_STRING(2, "R1_TS1_Temperature"), value);
}

int main(int argc, char *argv[]) {
    signal(SIGINT, stopHandler);
    signal(SIGTERM, stopHandler);

    UA_Server *server = UA_Server_new();
    UA_ServerConfig_setDefault(UA_Server_getConfig(server));

    //Check for arguments
    if(argc > 2)    //hostname or ip address and a port number are available
    {
        UA_Int16 port_number = atoi(argv[2]);
        UA_ServerConfig_setMinimal(UA_Server_getConfig(server), port_number, 0);
    }
    else
    {
        UA_ServerConfig_setDefault(UA_Server_getConfig(server));
    }
    
    if(argc > 1)
    {
        //hostname or ip address available
        //copy the hostname from char * to an open62541 variable
        UA_String hostname;
        UA_String_init(&hostname);
        hostname.length = strlen(argv[1]);
        hostname.data = (UA_Byte *) argv[1]; //da la dirección del apuntador de los argumentos.

        UA_ServerConfig_setCustomHostname(UA_Server_getConfig(server), hostname);
    }

    // agregamos un namespace to the server.
    UA_Int16 ns_room1 = UA_Server_addNamespace(server, "Room1");
    UA_LOG_INFO(UA_Log_Stdout, UA_LOGCATEGORY_USERLAND, "Newspace added with Ne. %d", ns_room1);

    // Creamos una variable de Temperature.
    UA_NodeId r1_tempsed_Id;
    UA_ObjectAttributes oAttr = UA_ObjectAttributes_default;
    UA_Server_addObjectNode(server, UA_NODEID_STRING(2, "R1_TS1_VendorName"),
                            UA_NODEID_NUMERIC(0, UA_NS0ID_OBJECTSFOLDER),
                            UA_NODEID_NUMERIC(0, UA_NS0ID_ORGANIZES),
                            UA_QUALIFIEDNAME(2, "Temperature sensor"), UA_NODEID_NUMERIC(0, UA_NS0ID_BASEOBJECTTYPE),
                            oAttr, NULL, &r1_tempsed_Id);

    // Agregamos descripción de las variables/sensores.
    UA_VariableAttributes vnAttr = UA_VariableAttributes_default;
    UA_String vendorName = UA_STRING("Valiot Ltd.");
    UA_Variant_setScalar(&vnAttr.value, &vendorName, &UA_TYPES[UA_TYPES_STRING]);
    UA_Server_addVariableNode(server, UA_NODEID_STRING(2, "R1_TS1_VendorName"), r1_tempsed_Id,
                            UA_NODEID_NUMERIC(0, UA_NS0ID_HASCOMPONENT),
                            UA_QUALIFIEDNAME(2, "VendorName"),
                            UA_NODEID_NUMERIC(0, UA_NS0ID_BASEDATAVARIABLETYPE), vnAttr, NULL, NULL);

    // Agregando número serial.
    UA_VariableAttributes snAttr = UA_VariableAttributes_default;
    UA_Int32 serialNumber = 12345321;
    UA_Variant_setScalar(&snAttr.value, &serialNumber, &UA_TYPES[UA_TYPES_INT32]);
    UA_Server_addVariableNode(server, UA_NODEID_STRING(2, "R1_TS1_SerialNumber"), r1_tempsed_Id,
                            UA_NODEID_NUMERIC(0, UA_NS0ID_HASCOMPONENT),
                            UA_QUALIFIEDNAME(2, "SerialNumber"),
                            UA_NODEID_NUMERIC(0, UA_NS0ID_BASEDATAVARIABLETYPE), snAttr, NULL, NULL);

    // Agregando número serial.
    UA_VariableAttributes tpAttr = UA_VariableAttributes_default;
    UA_Variant_setScalar(&tpAttr.value, &temperature, &UA_TYPES[UA_TYPES_DOUBLE]);
    UA_Server_addVariableNode(server, UA_NODEID_STRING(2, "R1_TS1_Temperature"), r1_tempsed_Id,
                            UA_NODEID_NUMERIC(0, UA_NS0ID_HASCOMPONENT),
                            UA_QUALIFIEDNAME(2, "Temperature"),
                            UA_NODEID_NUMERIC(0, UA_NS0ID_BASEDATAVARIABLETYPE), tpAttr, NULL, NULL);

    UA_ValueCallback callback ;
    callback.onRead = beforeReadTemperature;
    callback.onWrite = NULL;
    UA_Server_setVariableNode_valueCallback(server, UA_NODEID_STRING(2, "R1_TS1_Temperature"), callback);

    UA_StatusCode retval = UA_Server_run(server, &running);

    UA_Server_delete(server);
    return retval == UA_STATUSCODE_GOOD ? EXIT_SUCCESS : EXIT_FAILURE;
}
