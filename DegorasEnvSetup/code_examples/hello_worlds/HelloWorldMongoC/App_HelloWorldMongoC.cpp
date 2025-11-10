/***********************************************************************************************************************
 *  Copyright (C) 2025 Degoras Project Team
 *
 *  Authors:
 *      Ángel Vera Herrera       <avera@roa.es>   |  <angelvh.engr@gmail.com>
 *      Jesús Relinque Madroñal
 *
 *  Licensed under the MIT License.
 **********************************************************************************************************************/

/***********************************************************************************************************************
 *   HelloWorldMongoC –  Minimal mongoc example with nlohmann json
 **********************************************************************************************************************/

// C++ INCLUDES
#include <iostream>
#include <cstdlib>
#include <memory>
#include <string>

// BSON INCLUDES
#include <bson/bson.h>

// MONGOC INCLUDES
#include <mongoc/mongoc.h>

// NLOHMANN JSON INCLUDES
#include <nlohmann/json.hpp>

/** Custom deleter for bson_t */
struct BsonDeleter 
{
    void operator()(bson_t* b) const noexcept 
	{ 
		if (b) 
			bson_destroy(b); 
	}
};

// Aliases
using BsonPtr = std::unique_ptr<struct _bson_t, BsonDeleter>;

/**
 * @brief Convert a bson_t into canonical Extended JSON string.
 * @param b Pointer to bson_t.
 * @return std::string with canonical Extended JSON.
 */
static std::string bsonToJsonStr(const bson_t* b)
{
    if (!b) 
		return {};
    size_t len = 0;
    char* s = bson_as_canonical_extended_json(b, &len); 
    if (!s) 
		return {};
    std::string out{s, len};
    bson_free(s);
    return out;
}

/**
 * @brief Convert a bson_t into nlohmann::json.
 * @param b Pointer to bson_t.
 * @return json object parsed from canonical Extended JSON.
 * @warning Extended types (ObjectId, Date, etc.) appear as Extended JSON objects.
 */
static nlohmann::json bsonToJson(const bson_t* b)
{
    const std::string s = bsonToJsonStr(b);
    if (s.empty()) return nlohmann::json{};
    // Parse safely. Exceptions disabled to keep this sample minimal.
    try 
	{
        return nlohmann::json::parse(s);
    } 
	catch (...) 
	{
        return nlohmann::json{}; 
    }
}

/**
 * @brief Convert nlohmann::json to bson_t using libbson's JSON parser.
 * @param j nlohmann::json value. Must serialize to valid JSON or Extended JSON.
 * @return BsonPtr owning a newly created bson_t, or null on error.
 * @note libbson accepts standard JSON for basic types and MongoDB Extended JSON for special types.
 */
static BsonPtr jsonToBson(const nlohmann::json& j)
{
    const std::string dumped = j.dump();
    bson_error_t err{};
    bson_t* raw = bson_new_from_json(reinterpret_cast<const uint8_t*>(dumped.c_str()),
                                     dumped.size(), &err);
    if (!raw) 
	{
        std::cerr << "jsonToBson: parse error: " << err.message << '\n';
        return {};
    }
    return BsonPtr{raw};
}

/**
 * @brief Main entry point of the App_HelloWorldMongoC application.
 */
int main()
{
    // Initialize the driver and connect
	// -----------------------------------------------------------------------------

    mongoc_init();

    const char* uri_str = "mongodb://localhost:27017";
    mongoc_client_t* client = mongoc_client_new(uri_str);
    if (!client) 
	{
        std::cerr << "Failed to create client for URI: " << uri_str << std::endl;
        mongoc_cleanup();
        return EXIT_FAILURE;
    }

    // Get DB and collection
	// -----------------------------------------------------------------------------

    mongoc_collection_t* mcol = mongoc_client_get_collection(client, "my_db", "my_collection");

    // Optional: clear the collection
	// -----------------------------------------------------------------------------

	BsonPtr empty{bson_new()};
	mongoc_collection_delete_many(mcol, empty.get(), nullptr, nullptr, nullptr);

    // Insert documents using plain libbson
	// -----------------------------------------------------------------------------

    for (int i = 0; i < 3; ++i) 
	{
        BsonPtr doc{bson_new()};
        BSON_APPEND_UTF8(doc.get(), "name", (i == 0 ? "Ana" : (i == 1 ? "Luis" : "Maria")));
        BSON_APPEND_INT32(doc.get(), "age", (20 + i * 5));
        BSON_APPEND_BOOL(doc.get(), "active", (i % 2 == 0));
        BSON_APPEND_UTF8(doc.get(), "register_date", "2025-11-07");

        bson_error_t error{};
		
        if (!mongoc_collection_insert_one(mcol, doc.get(), nullptr, nullptr, &error)) 
		{
            std::cerr << "Insert error: " << error.message << std::endl;
        } 
		else 
		{
            std::cout << "Inserted document: " << i << std::endl;
        }
    }

    // Insert one document using nlohmann::json -> bson_t conversion
	// -----------------------------------------------------------------------------

    nlohmann::json jdoc = 
		{
			{"name", "Alice"},
			{"age", 33},
			{"active", true},
			{"tags", nlohmann::json::array({"test", "json"})},
			{"register_date", "2025-11-07"}
		};

	if (BsonPtr b = jsonToBson(jdoc)) 
	{
		bson_error_t error{};
		if (!mongoc_collection_insert_one(mcol, b.get(), nullptr, nullptr, &error)) 
		{
			std::cerr << "Insert (jsonToBson) error: " << error.message << std::endl;
		} 
		else 
		{
			std::cout << "Inserted document via jsonToBson." << std::endl;
		}
	}
	
    // Query all and print both as Extended JSON string and as nlohmann::json
    // -----------------------------------------------------------------------------

	BsonPtr query{bson_new()}; // empty -> match all
	mongoc_cursor_t* cursor =
		mongoc_collection_find_with_opts(mcol, query.get(), nullptr, nullptr);

	const bson_t* result = nullptr;
	std::cout << "Collection contents:" << std::endl;
	while (mongoc_cursor_next(cursor, &result)) 
	{
		// 1) Canonical Extended JSON string
		std::string ext = bsonToJsonStr(result);
		std::cout << "[extended]" << std::endl << ext << std::endl;

		// 2) nlohmann::json pretty
		nlohmann::json j = bsonToJson(result);
		std::cout << "[nlohmann] " << std::endl << j.dump(2) << std::endl;
	}

	if (mongoc_cursor_error(cursor, nullptr)) 
	{
		std::cerr << "Cursor error while iterating results\n";
	}
	mongoc_cursor_destroy(cursor);

	// -----------------------------------------------------------------------------

    // Cleanup
    mongoc_collection_destroy(mcol);
    mongoc_client_destroy(client);
    mongoc_cleanup();
	
	// All ok.
    return 0;
}

// =====================================================================================================================