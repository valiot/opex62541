#include <open62541.h>
#include <stdlib.h>

int main(void) {
    UA_Client *client = UA_Client_new();
    UA_ClientConfig_setDefault(UA_Client_getConfig(client));
    UA_StatusCode retval = UA_Client_connect(client, "opc.tcp://127.0.0.1:4840");
    if(retval != UA_STATUSCODE_GOOD) {
        printf("Error connection\n");
        UA_Client_delete(client);
        return (int)retval;        
    }

    /* Read the value attribute of the node. UA_Client_readValueAttribute is a
     * wrapper for the raw read service available as UA_Client_Service_read. */
    UA_Variant value; /* Variants can hold scalar values and arrays of any type */
    UA_Variant_init(&value);

    /* NodeId of the variable holding the temperature */
    retval = UA_Client_readValueAttribute(client,  UA_NODEID_STRING(2, "R1_TS1_Temperature"), &value);

    if(retval == UA_STATUSCODE_GOOD &&
       UA_Variant_hasScalarType(&value, &UA_TYPES[UA_TYPES_DOUBLE])) {
        UA_Double temperature = *(UA_Double *) value.data;
        UA_LOG_INFO(UA_Log_Stdout, UA_LOGCATEGORY_USERLAND, "Temperature is %f\n", temperature);
        printf("Temperature is %f\n", temperature);
        printf("Entre\n");
    }
    else
    {
        printf("Error\n");
    }
    // UA_Boolean trans = UA_Variant_hasScalarType(&value, &UA_TYPES[UA_TYPES_DOUBLE]);
    // UA_Double temperature = *(UA_Double *) value.data;
    // printf("Temperature is %f, status = %d, transaction = %d\n", temperature, retval, trans);

    /* Clean up */
    UA_Variant_clear(&value);
    UA_Client_delete(client); /* Disconnects the client internally */
    return EXIT_SUCCESS;
}