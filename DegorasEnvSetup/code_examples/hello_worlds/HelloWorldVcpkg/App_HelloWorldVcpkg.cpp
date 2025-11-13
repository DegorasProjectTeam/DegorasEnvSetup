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
 *   HelloWorldVcpkg –  Minimal C++ Example
 **********************************************************************************************************************/

// C++ INCLUDES
#include <fmt/core.h>  ///< fmt::print
#include <memory>
#include <string>

/**
 * @brief Main entry point of the App_HelloWorldFmt application.
 */
int main()
{
    // Print formatted message.
    fmt::print("HELLO WORLD\n");

    // Print with variable substitution.
    std::string name = "Degoras";
    int version = 1;
    fmt::print("Hello, {} v{}!\n", name, version);

    // All ok.
    return 0;
}

// =====================================================================================================================