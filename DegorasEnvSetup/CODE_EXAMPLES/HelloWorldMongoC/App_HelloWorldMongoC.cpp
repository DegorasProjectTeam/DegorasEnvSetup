#include <iostream>
#include <bson/bson.h>
#include <mongoc/mongoc.h>

int main(int argc, char* argv[]) {
    // Inicializar la librería
    mongoc_init();

    const char* uri_string = "mongodb://localhost:27017";
    mongoc_client_t* client = mongoc_client_new(uri_string);
    if (!client) {
        std::cerr << "No se pudo conectar a MongoDB con URI: " << uri_string << std::endl;
        return EXIT_FAILURE;
    }

    // Obtener base de datos y colección
    mongoc_collection_t* collection =
        mongoc_client_get_collection(client, "mi_bd", "mi_coleccion");

    // Limpiar la colección (opcional) para que esté vacía
    {
        bson_t* empty = bson_new();
        mongoc_collection_delete_many(collection, empty, NULL, NULL, NULL);
        bson_destroy(empty);
    }

    // Crear e insertar documentos
    for (int i = 0; i < 3; ++i) {
        bson_t* doc = bson_new();
        BSON_APPEND_UTF8(doc, "nombre", (i == 0 ? "Ana" : (i == 1 ? "Luis" : "María")));
        BSON_APPEND_INT32(doc, "edad", (20 + i * 5));
        BSON_APPEND_BOOL(doc, "activo", (i % 2 == 0));
        BSON_APPEND_UTF8(doc, "registro_fecha", "2025-11-07");

        bson_error_t error;
        if (!mongoc_collection_insert_one(collection, doc, NULL, NULL, &error)) {
            std::cerr << "Error insertando documento: " << error.message << std::endl;
        } else {
            std::cout << "Documento insertado correctamente: " << i << std::endl;
        }

        bson_destroy(doc);
    }

    // Opcional: consulta para mostrar lo que hay
    {
        bson_t* query = bson_new(); // vacía -> todos los documentos
        mongoc_cursor_t* cursor =
            mongoc_collection_find_with_opts(collection, query, NULL, NULL);
        const bson_t* result;
        std::cout << "Contenido actual de la colección:" << std::endl;
        while (mongoc_cursor_next(cursor, &result)) {
            char* str = bson_as_canonical_extended_json(result, NULL);
            std::cout << str << std::endl;
            bson_free(str);
        }
        bson_destroy(query);
        mongoc_cursor_destroy(cursor);
    }

    // Limpieza
    mongoc_collection_destroy(collection);
    mongoc_client_destroy(client);
    mongoc_cleanup();

    return EXIT_SUCCESS;
}
