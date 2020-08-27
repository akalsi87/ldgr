//! @file logger.hpp
//! @brief Logger

/*
 * zlib License
 *
 * (C) 2020 Aaditya Kalsi
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

#ifndef INCLUDED_LDGR_LOGGER_HPP
#define INCLUDED_LDGR_LOGGER_HPP

#include <ldgr/logentry.hpp>
#include <ldgr/logsink.hpp>

#include <fmt/ostream.h>

#include <algorithm>
#include <atomic>
#include <string>
#include <unordered_map>

namespace ldgr {

class logger {
    friend class log_registry;

    std::atomic<log_severity> d_level_;
    std::shared_ptr<pooled_log_buffer_factory> d_factory_;
    std::vector<std::shared_ptr<log_sink>> d_sinks_;
    std::string d_name_;
    std::mutex d_sinks_mutex_;

    logger(std::string name,
           std::shared_ptr<log_sink> sink,
           std::shared_ptr<pooled_log_buffer_factory> factory) noexcept
    : d_level_(log_severity::info)
    , d_factory_(std::move(factory))
    , d_sinks_(1, std::move(sink))
    , d_name_(std::move(name))
    , d_sinks_mutex_()
    {
    }

  public:
    logger(const logger&) = delete;
    logger& operator=(const logger&) = delete;

    fmt::string_view name() const noexcept
    {
        return fmt::string_view{d_name_.c_str(), d_name_.size()};
    }

    log_severity level() const noexcept
    {
        return d_level_.load(std::memory_order_acquire);
    }

    void add_sink(std::shared_ptr<log_sink> sink)
    {
        const std::lock_guard<std::mutex> guard{d_sinks_mutex_};
        for (const auto& s : d_sinks_) {
            if (s == sink) {
                return;
            }
        }
        d_sinks_.push_back(sink);
    }

    void remove_sink(std::shared_ptr<log_sink> sink)
    {
        const std::lock_guard<std::mutex> guard{d_sinks_mutex_};
        d_sinks_.erase(std::remove(d_sinks_.begin(), d_sinks_.end(), sink));
    }

    bool should_log(log_severity lvl) const noexcept
    {
        return lvl >= level();
    }

    void set_level(log_severity lvl) noexcept
    {
        d_level_.store(lvl, std::memory_order_release);
    }

    void log(const log_entry& entry)
    {
        auto cp = log_entry_util::copy_log_entry(entry, true, *d_factory_);
        const std::lock_guard<std::mutex> guard{d_sinks_mutex_};
        for (const auto& s : d_sinks_) {
            s->log(cp);
        }
    }
};

class log_registry {
    struct hasher {
        std::size_t operator()(const fmt::string_view& x) const noexcept
        {
            std::size_t h{0};
            for (auto c : x) {
                h = (h << 4u) + h + c;
            }
            return h;
        }
    };

    static log_registry& instance();

    std::shared_ptr<log_sink> d_default_sink_{log_sink_factory::stderr_sink()};
    std::shared_ptr<pooled_log_buffer_factory> d_factory_{
        pooled_log_buffer_factory::create()};
    std::unordered_map<fmt::string_view, std::shared_ptr<logger>, hasher>
        d_loggers_{std::make_pair(
            fmt::string_view{"ROOT", 4},
            std::shared_ptr<logger>{
                new logger{"ROOT", d_default_sink_, d_factory_}})};
    std::mutex d_logger_mutex_{};

  public:
    static logger& get(fmt::string_view logger_name)
    {
        auto& s = instance();
        const std::lock_guard<std::mutex> guard{s.d_logger_mutex_};
        auto it = s.d_loggers_.find(logger_name);
        if (it != s.d_loggers_.end()) {
            return *it->second;
        }
        auto l = std::shared_ptr<logger>(
            new logger{std::string{logger_name.data(), logger_name.size()},
                       s.d_default_sink_,
                       s.d_factory_});
        s.d_loggers_[l->name()] = l;
        return *l;
    }
};

} // namespace ldgr

#define LDGR__STR2(x) #x
#define LDGR__STR(x) LDGR__STR2(x)

#define LDGR__LOG_IMPL(lvl, cat, fmtstr, ...)                                 \
    do {                                                                      \
        auto& l = ::ldgr::log_registry::get(cat);                             \
        if (!l.should_log(::ldgr::log_severity::lvl)) {                       \
            break;                                                            \
        }                                                                     \
        ::ldgr::log_buffer_t buff;                                            \
        ::fmt::format_to(::std::back_inserter(buff), fmtstr, ##__VA_ARGS__);  \
        ::ldgr::log_entry entry{                                              \
            ::ldgr::log_severity::lvl,                                        \
            ::ldgr::fmtutil::to_view(cat),                                    \
            ::ldgr::fmtutil::to_view(__FILE__),                               \
            ::ldgr::fmtutil::to_view(LDGR__STR(__LINE__)),                    \
            ::std::chrono::system_clock::now(),                               \
            ::ldgr::fmtutil::to_view(buff)};                                  \
        l.log(entry);                                                         \
    } while (0)

#define LDGR_CAT_TRACE(cat, fmtstr, ...)                                      \
    LDGR__LOG_IMPL(trace, cat, fmtstr, ##__VA_ARGS__)

#define LDGR_CAT_DEBUG(cat, fmtstr, ...)                                      \
    LDGR__LOG_IMPL(debug, cat, fmtstr, ##__VA_ARGS__)

#define LDGR_CAT_INFO(cat, fmtstr, ...)                                       \
    LDGR__LOG_IMPL(info, cat, fmtstr, ##__VA_ARGS__)

#define LDGR_CAT_WARN(cat, fmtstr, ...)                                       \
    LDGR__LOG_IMPL(warn, cat, fmtstr, ##__VA_ARGS__)

#define LDGR_CAT_ERROR(cat, fmtstr, ...)                                      \
    LDGR__LOG_IMPL(error, cat, fmtstr, ##__VA_ARGS__)

#define LDGR_CAT_FATAL(cat, fmtstr, ...)                                      \
    LDGR__LOG_IMPL(fatal, cat, fmtstr, ##__VA_ARGS__)

#define LDGR_TRACE(fmtstr, ...) LDGR_CAT_TRACE("ROOT", fmtstr, ##__VA_ARGS__)

#define LDGR_DEBUG(fmtstr, ...) LDGR_CAT_DEBUG("ROOT", fmtstr, ##__VA_ARGS__)

#define LDGR_INFO(fmtstr, ...) LDGR_CAT_INFO("ROOT", fmtstr, ##__VA_ARGS__)

#define LDGR_WARN(fmtstr, ...) LDGR_CAT_WARN("ROOT", fmtstr, ##__VA_ARGS__)

#define LDGR_ERROR(fmtstr, ...) LDGR_CAT_ERROR("ROOT", fmtstr, ##__VA_ARGS__)

#define LDGR_FATAL(fmtstr, ...) LDGR_CAT_FATAL("ROOT", fmtstr, ##__VA_ARGS__)

#endif /*INCLUDED_LDGR_LOGGER_HPP*/
