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
 *   HelloWorldCxx – Minimal mongocxx example with nlohmann json
 **********************************************************************************************************************/

// C++ INCLUDES
#include <iostream>
#include <chrono>
#include <cstdint>

// NLOHMANN JSON
#include <nlohmann/json.hpp>

// BSONCXX INCLUDES
#include <bsoncxx/json.hpp>
#include <bsoncxx/builder/basic/document.hpp>
#include <bsoncxx/builder/basic/kvp.hpp>
#include <bsoncxx/types.hpp>

// MONGOCXX INCLUDES
#include <mongocxx/client.hpp>
#include <mongocxx/instance.hpp>
#include <mongocxx/uri.hpp>
#include <mongocxx/exception/exception.hpp>

/**
 * @brief Convert a BSON CXX document/view to nlohmann::json via Extended JSON.
 * @param view BSON view.
 * @return JSON object.
 * @note Extended types (ObjectId, Date, etc.) are represented with Extended JSON objects.
 */
static nlohmann::json bsoncxxToNjson(const bsoncxx::document::view& view)
{
    const std::string s = bsoncxx::to_json(view);
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
 * @brief Convert nlohmann::json to BSON document using Extended JSON parser.
 * @param j JSON object (may include Extended JSON for special types).
 * @return BSON document::value (owning).
 */
static bsoncxx::document::value njsonToBsoncxx(const nlohmann::json& j)
{
    const std::string dumped = j.dump();
    return bsoncxx::from_json(dumped);
}

/**
 * @brief Main entry point of the App_HelloWorldMongoCxx application.
 */
int main()
{
	// Initialize the driver and connect
	// -----------------------------------------------------------------------------

	// The mongocxx::instance constructor and destructor initialize and shut down the driver,
    // respectively. Therefore, a mongocxx::instance must be created before using the driver and
    // must remain alive for as long as the driver is in use.
	mongocxx::instance instance{}; 

    const std::string uri_str = "mongodb://localhost:27017";
    mongocxx::client client;
    try
    {
        client = mongocxx::client(mongocxx::uri{uri_str});
    }
    catch (const mongocxx::exception& ex)
    {
        std::cerr << "[Error] Failed to create MongoDB client: " << ex.what() << std::endl;
        return 1;
    }

    // Get DB and collection
	// -----------------------------------------------------------------------------

    mongocxx::database db = client["my_db"];
    mongocxx::collection col = db["my_collection"];

    // Optional: clear the collection
	// -----------------------------------------------------------------------------

    try 
	{
        auto delres = col.delete_many({});               
        if (delres) 
		{
            std::cout << "[Info] Cleared collection (" 
                      << delres->deleted_count()        
                      << " documents deleted)" << std::endl;
        } 
		else 
		{
            std::cout << "[Warn] delete_many returned no result\n";
        }
    } 
	catch (const mongocxx::exception& ex) 
	{
        std::cerr << "[Error] delete_many failed: " << ex.what() << std::endl;
    }

    // Insert documents using plain libbson
	// -----------------------------------------------------------------------------

    for (int i = 0; i < 3; ++i)
    {
        bsoncxx::builder::basic::document doc;
        doc.append(bsoncxx::builder::basic::kvp("name", (i == 0 ? "Ana" : (i == 1 ? "Luis" : "Maria"))));
        doc.append(bsoncxx::builder::basic::kvp("age", 20 + i * 5));
        doc.append(bsoncxx::builder::basic::kvp("active", (i % 2 == 0)));
        doc.append(bsoncxx::builder::basic::kvp("register_date", "2025-11-07"));

        try
        {
            auto result = col.insert_one(doc.view());
            if (result)
                std::cout << "[OK] Inserted document " << i << std::endl;
            else
                std::cout << "[Warn] Insert operation returned no result (document " << i << ")" << std::endl;
        }
        catch (const mongocxx::exception& ex)
        {
            std::cerr << "[Error] Insert failed (" << i << "): " << ex.what() << std::endl;
        }
    }

    // Insert one document using nlohmann::json
	// -----------------------------------------------------------------------------

    nlohmann::json jdoc = {
        {"name", "Alice"},
        {"age", 33},
        {"active", true},
        {"tags", nlohmann::json::array({"test", "json"})},
        {"register_date", "2025-11-07"}};

    try
    {
        bsoncxx::document::value bdoc = njsonToBsoncxx(jdoc);
        auto result = col.insert_one(bdoc.view());
        if (result)
            std::cout << "[OK] Inserted JSON document 'Alice'" << std::endl;
    }
    catch (const mongocxx::exception& ex)
    {
        std::cerr << "[Error] Insert from JSON failed: " << ex.what() << std::endl;
    }

    // Query and print all documents
	// -----------------------------------------------------------------------------

    try
    {
        mongocxx::cursor cursor = col.find({});
        std::cout << "[Info] Collection contents:" << std::endl;

        for (const bsoncxx::document::view& doc : cursor)
        {
            std::cout << "[Extended JSON]" << std::endl;
            std::cout << bsoncxx::to_json(doc) << std::endl;

            nlohmann::json j = bsoncxxToNjson(doc);
            std::cout << "[nlohmann::json]" << std::endl << j.dump(2) << std::endl;
        }
    }
    catch (const mongocxx::exception& ex)
    {
        std::cerr << "[Error] Query failed: " << ex.what() << std::endl;
    }

	// -----------------------------------------------------------------------------

    std::cout << "[Done] All operations completed successfully." << std::endl;
	
	// All ok.
    return 0;
}

// =====================================================================================================================