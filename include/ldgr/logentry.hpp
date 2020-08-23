//! @file logentry.hpp
//! @brief Log entry.

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

#ifndef INCLUDED_LDGR_LOGENTRY_HPP
#define INCLUDED_LDGR_LOGENTRY_HPP

#include <ldgr/exports.h>
#include <ldgr/fmtutil.hpp>
#include <ldgr/logseverity.hpp>

#include <fmt/format.h>

#include <cassert>
#include <chrono>
#include <ctime>
#include <memory>
#include <mutex>

namespace ldgr {

using time_point = std::chrono::system_clock::time_point;

struct log_entry {
    log_severity severity;
    fmt::string_view name;
    fmt::string_view file;
    fmt::string_view line;
    time_point when;
    fmt::string_view message;
};

struct log_entry_fmt {
    log_severity severity;
    fmt::string_view name;
    fmt::string_view file;
    fmt::string_view line;
    std::tm time_struct;
    long microseconds;
    bool is_local;
    fmt::string_view message;

    long milliseconds() const noexcept
    {
        return (microseconds / 1000) + ((microseconds % 1000) >= 500);
    }
};

struct log_entry_fmt_cp {
    log_entry_fmt entry;
    std::shared_ptr<log_buffer_t> buffer;
};

struct default_log_buffer_factory {
    std::shared_ptr<log_buffer_t> operator()() const
    {
        return std::make_shared<log_buffer_t>();
    }
};

class LDGR_API pooled_log_buffer_factory
: public std::enable_shared_from_this<pooled_log_buffer_factory> {
    struct node {
        node* next = nullptr;
        pooled_log_buffer_factory* pool = nullptr;
        log_buffer_t buffer{};
    };

    struct mem_block {
        mem_block* next;
    };

    template <class T>
    struct ctrl_block_alloc {
        std::shared_ptr<pooled_log_buffer_factory> d_pool_;

        ctrl_block_alloc(std::shared_ptr<pooled_log_buffer_factory>&& p)
        : d_pool_(std::move(p))
        {
        }

        using value_type = T;

        template <class U>
        ctrl_block_alloc(const ctrl_block_alloc<U>& rhs) noexcept
        : d_pool_(rhs.d_pool_)
        {
        }
        template <class U>
        ctrl_block_alloc(ctrl_block_alloc<U>&& rhs) noexcept
        : d_pool_(std::move(rhs.d_pool_))
        {
        }

        inline T* allocate(std::size_t n)
        {
            assert(n == 1);
            auto* p = d_pool_.get();
            {
                std::lock_guard<std::mutex> guard(
                    p->d_free_ctrl_blocks_mutex_);
                if (auto* cb = p->d_free_ctrl_blocks_) {
                    p->d_free_ctrl_blocks_ = cb->next;
                    return reinterpret_cast<T*>(cb);
                }
            }
            return static_cast<T*>(::operator new(sizeof(T)));
        }

        inline void deallocate(T* ptr, std::size_t n)
        {
            assert(n == 1);
            auto* cb = reinterpret_cast<mem_block*>(ptr);
            auto* p = d_pool_.get();
            std::lock_guard<std::mutex> guard(p->d_free_ctrl_blocks_mutex_);
            cb->next = p->d_free_ctrl_blocks_;
            p->d_free_ctrl_blocks_ = cb;
        }

        template <class U>
        friend bool operator==(const ctrl_block_alloc<T>& x,
                               const ctrl_block_alloc<U>& y) noexcept
        {
            return x.d_pool_ == y.d_pool_;
        }
        template <class U>
        friend bool operator!=(const ctrl_block_alloc<T>& x,
                               const ctrl_block_alloc<U>& y) noexcept
        {
            return x.d_pool_ != y.d_pool_;
        }
    };

    struct clear_node {
        inline void operator()(node* n) const noexcept
        {
            n->buffer.clear();
            auto* p = n->pool;
            std::lock_guard<std::mutex> guard{p->d_free_list_mutex_};
            n->next = p->d_free_list_;
            p->d_free_list_ = n;
        }
    };

    node* d_free_list_;
    mutable std::mutex d_free_list_mutex_;
    mem_block* d_free_ctrl_blocks_;
    mutable std::mutex d_free_ctrl_blocks_mutex_;

    pooled_log_buffer_factory()
    : d_free_list_(nullptr)
    , d_free_list_mutex_()
    , d_free_ctrl_blocks_(nullptr)
    , d_free_ctrl_blocks_mutex_()
    {
    }

  public:
    static std::shared_ptr<pooled_log_buffer_factory> create()
    {
        return std::shared_ptr<pooled_log_buffer_factory>(
            new pooled_log_buffer_factory{});
    }

    ~pooled_log_buffer_factory() noexcept;

    pooled_log_buffer_factory(const pooled_log_buffer_factory&) = delete;
    pooled_log_buffer_factory&
    operator=(const pooled_log_buffer_factory&) = delete;

    inline std::shared_ptr<log_buffer_t> operator()()
    {
        node* n = nullptr;
        {
            std::lock_guard<std::mutex> guard{d_free_list_mutex_};
            if ((n = d_free_list_)) {
                d_free_list_ = n->next;
                n->next = nullptr;
            }
        }

        if (!n) {
            n = new node{};
            n->pool = this;
        }

        return std::shared_ptr<log_buffer_t>(
            std::shared_ptr<node>{
                n, clear_node{}, ctrl_block_alloc<node>{shared_from_this()}},
            &n->buffer);
    }
};

struct log_entry_util {
    static log_entry_fmt to_log_entry_fmt(const log_entry& entry,
                                          bool local_time = false) noexcept
    {
        namespace chr = std::chrono;
        const auto dur = chr::duration_cast<chr::microseconds>(
            entry.when.time_since_epoch());
        auto ct = dur.count();
        auto time = static_cast<std::time_t>(ct / 1000000);
        auto micros = ct % 1000000;

        log_entry_fmt out{entry.severity,
                          entry.name,
                          entry.file,
                          entry.line,
                          {},
                          micros,
                          local_time,
                          entry.message};
        if (local_time) {
            ::localtime_r(&time, &out.time_struct);
        }
        else {
            ::gmtime_r(&time, &out.time_struct);
        }
        return out;
    }

    template <class FACTORY = default_log_buffer_factory>
    static log_entry_fmt_cp copy_log_entry_fmt(const log_entry_fmt& entry_fmt,
                                               FACTORY&& factory = FACTORY())
    {
        log_entry_fmt_cp out{};
        out.buffer = std::forward<FACTORY>(factory)();

        std::size_t off{0};
        auto& buff = *(out.buffer);
        buff.reserve(entry_fmt.name.size() + entry_fmt.file.size() +
                     entry_fmt.line.size() + entry_fmt.message.size());

        auto append_str = [&off, &buff](const fmt::string_view& view) {
            fmtutil::append(buff, view);
            auto out = fmt::string_view(buff.data() + off, view.size());
            off += view.size();
            return out;
        };

        out.entry.severity = entry_fmt.severity;
        out.entry.name = append_str(entry_fmt.name);
        out.entry.file = append_str(entry_fmt.file);
        out.entry.line = append_str(entry_fmt.line);
        out.entry.time_struct = entry_fmt.time_struct;
        out.entry.microseconds = entry_fmt.microseconds;
        out.entry.is_local = entry_fmt.is_local;
        out.entry.message = append_str(entry_fmt.message);
        return out;
    }

    template <class FACTORY = default_log_buffer_factory>
    static log_entry_fmt_cp copy_log_entry(const log_entry& entry,
                                           bool local_time = false,
                                           FACTORY&& factory = FACTORY())
    {
        return copy_log_entry_fmt(to_log_entry_fmt(entry, local_time),
                                  std::forward<FACTORY>(factory));
    }
};

} // namespace ldgr

#endif /*INCLUDED_LDGR_LOGENTRY_HPP*/
