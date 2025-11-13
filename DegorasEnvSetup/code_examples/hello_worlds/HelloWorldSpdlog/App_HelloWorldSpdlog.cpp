/***********************************************************************************************************************
 *  Copyright (C) 2025 Degoras Project Team
 *
 *  Authors:
 *      Ángel Vera Herrera
 *		    <avera@roa.es>
 *		    <angelvh.engr@gmail.com>
 *      Jesús Relinque Madroñal
 *
 *  Licensed under the MIT License.
 **********************************************************************************************************************/

/***********************************************************************************************************************
 *   HelloWorldSpdlog –  Minimal spdlog example with nlohmann json
 **********************************************************************************************************************/

// STD INCLUDES
#include <iostream>
#include <cstdlib>
#include <memory>
#include <string>
#include <chrono>
#include <vector>
#include <thread>
#include <filesystem>

// JSON INCLUDES
#include <nlohmann/json.hpp>

// SPDLOG INCLUDES
#include <spdlog/spdlog.h>
#include <spdlog/async.h>
#include <spdlog/sinks/daily_file_sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/sinks/basic_file_sink.h>

// PLATFORM-SPECIFIC
#if defined(_WIN32)
    #include <windows.h>
#elif defined(__linux__)
    #include <unistd.h>     
#endif

// Constant expresions.
constexpr std::string_view kLogger1 = "ExampleDefaultLogger";
constexpr std::string_view kLogger2 = "ExampleAuxLogger";
constexpr int kNumThreads = 4;

/**
 * @brief Global configuration for spdlog asynchronous logging.
 *
 * This structure holds settings that affect the shared async thread pool
 * and the periodic flushing policy.
 */
struct SpdlogGlobalConfig
{
    /**
     * @brief Default constructor initializing recommended values.
     */
    SpdlogGlobalConfig() noexcept :
        queue_size(8192),
        thread_count(1),
        flush_interval(std::chrono::seconds{3}),
        use_flush_every(true)
    {}

    std::size_t queue_size;              ///< Global async thread pool queue size.
    std::size_t thread_count;            ///< Global async thread pool worker thread count.
    std::chrono::seconds flush_interval; ///< Interval used for spdlog::flush_every().
    bool use_flush_every;                ///< Enable periodic flushing with flush_every().
};

/**
 * @brief Per-logger configuration for spdlog asynchronous loggers.
 *
 * This structure holds settings for each individual logger: sinks, levels
 * and overflow policy.
 */
struct SpdlogLogConfig
{
    /**
     * @brief Default constructor initializing recommended values.
     */
    SpdlogLogConfig() noexcept :
        logger_name(std::string()),
        file_path(std::string()),
        log_pattern("[%Y-%m-%dT%H:%M:%S.%f][%P][%t][%^%L%$] %v"),
        enable_console(true),
        enable_file(false),
        set_default(false),
        console_level(spdlog::level::info),
        file_level(spdlog::level::debug),
        logger_level(spdlog::level::trace),
        flush_on(spdlog::level::warn),
        overflow_pol(spdlog::async_overflow_policy::overrun_oldest),
        use_daily_file(true)
    {}

    std::string logger_name;                     ///< Logger name (used in spdlog registry).
    std::string file_path;                       ///< Path to the log file (daily or basic sink).
    std::string log_pattern;                     ///< Pattern for the logs.
    bool enable_console;                         ///< Enable console sink.
    bool enable_file;                            ///< Enable file sink.
    bool set_default;                            ///< Set this logger as the global default logger.
    spdlog::level::level_enum console_level;     ///< Minimum log level for console sink.
    spdlog::level::level_enum file_level;        ///< Minimum log level for file sink.
    spdlog::level::level_enum logger_level;      ///< Minimum log level accepted by the logger.
    spdlog::level::level_enum flush_on;          ///< Force flush when log >= this level.
    spdlog::async_overflow_policy overflow_pol;  ///< Overflow handling when queue is full.
    bool use_daily_file;                         ///< Use daily_file_sink_mt (true) or basic_file_sink_mt (false).
};

/**
 * @brief Initialize global spdlog async thread pool and time behavior.
 *
 * @param cfg Global configuration for async logging.
 */
inline void initSpdlog(const SpdlogGlobalConfig& cfg)
{
    // Initialize global async thread pool.
    spdlog::init_thread_pool(cfg.queue_size, cfg.thread_count);
    
    // Optionally enable periodic flushing for all registered loggers.
    if (cfg.use_flush_every)
        spdlog::flush_every(cfg.flush_interval);
}

/**
 * @brief Create and register an asynchronous spdlog logger using SpdlogLogConfig.
 *
 * Uses the global async thread pool initialized by initSpdlog().
 *
 * @param cfg Per-logger configuration structure.
 * @return std::shared_ptr<spdlog::logger> The created logger, or nullptr if no sinks are enabled.
 */
inline std::shared_ptr<spdlog::logger> registerSpdlogLogger(const SpdlogLogConfig& cfg)
{
    // Container.
    std::vector<spdlog::sink_ptr> sinks;
    sinks.reserve(2);

    // Console sink.
    if (cfg.enable_console)
    {
        auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
        console_sink->set_pattern(cfg.log_pattern);
        console_sink->set_level(cfg.console_level);
        sinks.push_back(console_sink);
    }

    // File sink.
    if (cfg.enable_file)
    {
        spdlog::sink_ptr file_sink;

        if (cfg.use_daily_file)
            file_sink = std::make_shared<spdlog::sinks::daily_file_sink_mt>(cfg.file_path, 0, 0);
        else
            file_sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(cfg.file_path, false);
        
        // Configure the sink.
        file_sink->set_pattern(cfg.log_pattern);
        file_sink->set_level(cfg.file_level);
        sinks.push_back(file_sink);
    }

    // If no sinks at all do NOT create logger.
    if (sinks.empty())
        return nullptr;

    // Create async logger using the global thread pool.
    auto logger = std::make_shared<spdlog::async_logger>(
        cfg.logger_name,
        sinks.begin(),
        sinks.end(),
        spdlog::thread_pool(),             
        cfg.overflow_pol);

    // Set the level and the flush on.
    logger->set_level(cfg.logger_level);
    logger->flush_on(cfg.flush_on);

    // Register logger in spdlog registry.
    spdlog::register_logger(logger);

    // Optionally set as default logger.
    if (cfg.set_default)
        spdlog::set_default_logger(logger);

    // Return the logger.
    return logger;
}

/**
 * @brief Example worker function for logs with threads.
 */
void workerThreadFunc(int id)
{
    // Retrieve the auxiliar logger by constexpr name.
    auto aux_logger    = spdlog::get(kLogger2.data());

    // Example JSON payload
    nlohmann::json payload = {
        {"worker_id",  id},
        {"status",     "running"},
        {"timestamp",  std::chrono::system_clock::now().time_since_epoch().count()},
    };

    // Log using global/default logger (if any).
    spdlog::debug("Worker {} payload (global): {}", id, payload.dump());
    spdlog::info("Worker {} payload (global): {}", id, payload.dump());
    spdlog::warn("Worker {} payload (global): {}", id, payload.dump());
    spdlog::error("Worker {} payload (global): {}", id, payload.dump());

    // Log using auxiliary logger, if available.
    if (aux_logger)
    {
        aux_logger->debug("Worker {} payload (aux): {}", id, payload.dump());
        aux_logger->info("Worker {} payload (aux): {}", id, payload.dump());
        aux_logger->warn("Worker {} payload (aux): {}", id, payload.dump());
        aux_logger->error("Worker {} payload (aux): {}", id, payload.dump());
    }
}

inline std::filesystem::path getExecutableDir()
{
#if defined(_WIN32)
    char buffer[MAX_PATH];
    DWORD size = GetModuleFileNameA(nullptr, buffer, MAX_PATH);
    if (size == 0 || size == MAX_PATH)
        return std::filesystem::current_path();
    return std::filesystem::path(buffer).parent_path();
#elif defined(__linux__)
    char buffer[4096];
    ssize_t size = readlink("/proc/self/exe", buffer, sizeof(buffer)-1);
    if (size <= 0)
        return std::filesystem::current_path();
    buffer[size] = '\0';
    return std::filesystem::path(buffer).parent_path();
#else
    // Fallback for unknown platforms
    return std::filesystem::current_path();
#endif
}

/**
 * @brief Main entry point of the App_HelloWorldSpdlog application.
 */
int main()
{
    // Get the executable dir.
    std::string logs_dir = getExecutableDir().string() + "/logs";
     
    // Global log config.
    SpdlogGlobalConfig gcfg;
    gcfg.queue_size     = 8192;
    gcfg.thread_count   = 1;
    gcfg.flush_interval = std::chrono::seconds{5};
    gcfg.use_flush_every = true;
    
    // Default logger (kLogger1).
    SpdlogLogConfig cfg1;
    cfg1.logger_name    = std::string(kLogger1);
    cfg1.file_path = logs_dir + "/" + std::string(kLogger1) + ".log";
    cfg1.enable_console = true;
    cfg1.enable_file    = true;
    cfg1.set_default    = true;                    
    cfg1.console_level  = spdlog::level::info;
    cfg1.file_level     = spdlog::level::debug;
    cfg1.logger_level   = spdlog::level::trace;
    cfg1.flush_on       = spdlog::level::warn;
    cfg1.use_daily_file = true;
    
    // Auxiliar logger (kLogger1).
    SpdlogLogConfig cfg2;
    cfg2.logger_name    = std::string(kLogger2);
    cfg2.file_path = logs_dir + "/" + std::string(kLogger2) + ".log";
    cfg2.enable_console = false;                   
    cfg2.enable_file    = true;
    cfg2.set_default    = false;                    
    cfg2.console_level  = spdlog::level::info;
    cfg2.file_level     = spdlog::level::debug;
    cfg2.logger_level   = spdlog::level::debug;
    cfg2.flush_on       = spdlog::level::warn;
    cfg2.use_daily_file = true;
    
    // Init spdlog.
    initSpdlog(gcfg);
    
    // Register default logger.
    auto global_logger = registerSpdlogLogger(cfg1);
    if (!global_logger)
    {
        std::cout << "[ERROR] Failed to create global logger!" << std::endl;
        return 1;
    }
    spdlog::info("Global logger [{}] initialized.", kLogger1);

    // Register auxiliar logger.
    auto aux_logger = registerSpdlogLogger(cfg2);
    if (!aux_logger)
    {
        std::cout << "[ERROR] Failed to create auxiliar logger!" << std::endl;
        return 1;
    }
    aux_logger->info("Auxiliary logger [{}] initialized.", kLogger2);

    // 4) Worker threads
    std::vector<std::thread> threads;
    for (int i = 0; i < kNumThreads; ++i)
    {
        threads.emplace_back(workerThreadFunc, i);
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }
    for (auto &th : threads)
        th.join();
        
    // Finalize all logs.
    spdlog::shutdown();
    
	// All ok.
    return 0;
}

// =====================================================================================================================