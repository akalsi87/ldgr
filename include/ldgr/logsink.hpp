//! @file logsink.hpp
//! @brief Log sink.

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

#ifndef INCLUDED_LDGR_LOGSINK_HPP
#define INCLUDED_LDGR_LOGSINK_HPP

#include <ldgr/exports.h>
#include <ldgr/fmtutil.hpp>
#include <ldgr/logentry.hpp>

#include <fmt/compile.h>
#include <fmt/format.h>

#include <atomic>
#include <cassert>
#include <cstring>
#include <functional>
#include <mutex>

namespace ldgr {

LDGR_API void default_formatter(log_buffer_t& buff,
                                const log_entry_fmt_cp& ent,
                                std::time_t& cached_time,
                                std::string& cached_str);

struct log_formatter {
    using format_fn = void (*)(log_buffer_t&,
                               const log_entry_fmt_cp&,
                               std::time_t& cached_time,
                               std::string& cached_str);

    struct as_vec {
    };

    log_formatter(format_fn f): d_fmt_fn_{f}, d_is_vec_{false}
    {
    }

    log_formatter(const as_vec&): d_is_vec_{true}
    {
        ::new ((void*)&d_vec_) std::vector<format_fn>{};
    }

    log_formatter(const log_formatter& fmt)
    {
        d_is_vec_ = fmt.d_is_vec_;
        if (d_is_vec_) {
            ::new ((void*)&d_vec_) std::vector<format_fn>(fmt.vec());
        }
        else {
            d_fmt_fn_ = fmt.d_fmt_fn_;
        }
        d_cached_time_ = fmt.d_cached_time_;
        d_cached_str_ = fmt.d_cached_str_;
    }

    log_formatter& operator=(const log_formatter&) = delete;

    ~log_formatter()
    {
        if (is_vec()) {
            vec().~vector();
        }
    }

    void format(log_buffer_t& buff, const log_entry_fmt_cp& ent) const
    {
        if (d_is_vec_) {
            for (auto f : vec()) {
                f(buff, ent, d_cached_time_, d_cached_str_);
            }
        }
        else {
            d_fmt_fn_(buff, ent, d_cached_time_, d_cached_str_);
        }
    }

    std::vector<format_fn>& vec()
    {
        assert(d_is_vec_);
        return *static_cast<std::vector<format_fn>*>((void*)&d_vec_);
    }

    const std::vector<format_fn>& vec() const
    {
        assert(d_is_vec_);
        return *static_cast<std::vector<format_fn>*>((void*)&d_vec_);
    }

    bool is_vec() const noexcept
    {
        return d_is_vec_;
    }

  private:
    union {
        format_fn d_fmt_fn_;
        std::aligned_storage_t<sizeof(std::vector<format_fn>)> d_vec_;
    };
    bool d_is_vec_{false};
    mutable std::time_t d_cached_time_{};
    mutable std::string d_cached_str_{};
};

class LDGR_API log_sink {
  public:
    virtual ~log_sink();

    void log(const log_entry_fmt_cp& entry)
    {
        if (!should_log(entry.entry.severity)) {
            return;
        }
        log_buffer_t buff;
        formatter()->format(buff, entry);
        do_log(buff);
    }

    void flush()
    {
        do_flush();
    }

    log_severity level() const noexcept
    {
        return d_level_.load(std::memory_order_acquire);
    }

    bool should_log(log_severity lvl) const noexcept
    {
        return lvl >= level();
    }

    std::shared_ptr<const log_formatter> formatter() const noexcept
    {
        std::lock_guard<std::mutex> guard{d_formatter_mutex_};
        return d_formatter_;
    }

    void set_level(log_severity lvl) noexcept
    {
        d_level_.store(lvl, std::memory_order_release);
    }

    void set_formatter(std::shared_ptr<const log_formatter> formatter)
    {
        std::lock_guard<std::mutex> guard{d_formatter_mutex_};
        d_formatter_ = std::move(formatter);
    }

  protected:
    std::atomic<log_severity> d_level_{log_severity::trace};
    std::shared_ptr<const log_formatter> d_formatter_{default_fmt()};
    mutable std::mutex d_formatter_mutex_{};

  private:
    virtual void do_log(const log_buffer_t& buff) = 0;
    virtual void do_flush() = 0;

    static std::shared_ptr<const log_formatter> default_fmt();
};

struct LDGR_API log_sink_factory {
    static std::shared_ptr<log_sink> stdout_sink();

    static std::shared_ptr<log_sink> stderr_sink();
};

} // namespace ldgr

#endif /*INCLUDED_LDGR_LOGSINK_HPP*/
