//! @file fmtutil.hpp
//! @brief fmt library utilities.

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

#ifndef INCLUDED_LDGR_FMTUTIL_HPP
#define INCLUDED_LDGR_FMTUTIL_HPP

#include <ldgr/logseverity.hpp>

#include <fmt/compile.h>
#include <fmt/format.h>

#include <chrono>
#include <cstddef>
#include <ctime>
#include <memory>

namespace ldgr {

template <std::size_t SIZE>
using buffer_t = fmt::basic_memory_buffer<char, SIZE>;

struct fmtutil {
    template <std::size_t PREC, class INT, std::size_t SIZE>
    static constexpr buffer_t<SIZE>& append_pad_int(buffer_t<SIZE>& dest,
                                                    INT n)
    {
        static_assert(PREC >= 1 && PREC <= 6, "Unaccounted for.");
        constexpr INT s_table[] = {1000000, 100000, 10000, 1000, 100, 10, 1};

        if constexpr (PREC == 1) {
            dest.push_back('0' + n);
        }
        else if constexpr (PREC == 2) {
            dest.push_back('0' + (n / 10));
            dest.push_back('0' + (n % 10));
        }
        else {
            constexpr auto div = *(std::end(s_table) - PREC);
            dest.push_back('0' + (n / div));
            append_pad_int<PREC - 1, INT, SIZE>(dest, n % div);
        }
        return dest;
    }

    template <std::size_t SIZE, class INT>
    static buffer_t<SIZE>& append(buffer_t<SIZE>& dest, INT n)
    {
        fmt::format_int f{n};
        dest.append(f.data(), f.data() + f.size());
        return dest;
    }

    template <std::size_t SIZE>
    static constexpr buffer_t<SIZE>& append(buffer_t<SIZE>& dest,
                                            const std::tm& val)
    {
        append_pad_int<4>(dest, val.tm_year + 1900);
        append(dest, '-');
        append_pad_int<2>(dest, val.tm_mon + 1);
        append(dest, '-');
        append_pad_int<2>(dest, val.tm_mday);
        append(dest, ' ');
        append_pad_int<2>(dest, val.tm_hour);
        append(dest, ':');
        append_pad_int<2>(dest, val.tm_min);
        append(dest, ':');
        return append_pad_int<2>(dest, val.tm_sec);
    }

    template <std::size_t SIZE, class CLOCK, class DUR>
    static constexpr buffer_t<SIZE>&
    append(buffer_t<SIZE>& dest,
           const std::chrono::time_point<CLOCK, DUR>& val,
           bool local_time = false)
    {
        return append(dest, val.time_since_epoch(), local_time);
    }

    template <std::size_t SIZE, class REP, class PER>
    static constexpr buffer_t<SIZE>&
    append(buffer_t<SIZE>& dest,
           const std::chrono::duration<REP, PER>& dur,
           bool local_time = false)
    {
        namespace chr = std::chrono;
        auto ct = dur.count();
        auto time = static_cast<std::time_t>(ct / 1000000);
        auto micros = ct % 1000000;
        std::tm tm_val{};
        if (local_time) {
            ::localtime_r(&time, &tm_val);
        }
        else {
            ::gmtime_r(&time, &tm_val);
        }
        append(dest, tm_val);
        append(dest, '.');
        append_pad_int<6>(dest, micros);
        if (!local_time) {
            append(dest, 'Z');
        }
        return dest;
    }

    template <std::size_t SIZE, std::size_t STR_SIZE>
    static constexpr buffer_t<SIZE>& append(buffer_t<SIZE>& dest,
                                            const char (&str)[STR_SIZE])
    {
        dest.append(std::begin(str), std::end(str));
        return dest;
    }

    template <std::size_t SIZE>
    static constexpr buffer_t<SIZE>& append(buffer_t<SIZE>& dest,
                                            fmt::string_view view)
    {
        dest.append(view.begin(), view.end());
        return dest;
    }

    template <std::size_t SIZE>
    static constexpr buffer_t<SIZE>& append(buffer_t<SIZE>& dest, char ch)
    {
        dest.push_back(ch);
        return dest;
    }

    template <std::size_t SIZE, int N>
    static constexpr buffer_t<SIZE>&
    append(buffer_t<SIZE>& dest, log_severity sev, const char (&sev_fmt)[N])
    {
        switch (sev) {
            case log_severity::off:
                fmt::format_to(dest, sev_fmt, "OFF");
                break;
            case log_severity::trace:
                fmt::format_to(dest, sev_fmt, "TRACE");
                break;
            case log_severity::debug:
                fmt::format_to(dest, sev_fmt, "DEBUG");
                break;
            case log_severity::info:
                fmt::format_to(dest, sev_fmt, "INFO");
                break;
            case log_severity::warn:
                fmt::format_to(dest, sev_fmt, "WARN");
                break;
            case log_severity::error:
                fmt::format_to(dest, sev_fmt, "ERROR");
                break;
            case log_severity::fatal:
                fmt::format_to(dest, sev_fmt, "FATAL");
                break;
        }
        return dest;
    }

    template <std::size_t SIZE>
    static constexpr buffer_t<SIZE>& append(buffer_t<SIZE>& dest,
                                            log_severity sev)
    {
        switch (sev) {
            case log_severity::off:
                fmt::format_to(
                    std::back_inserter(dest), FMT_COMPILE("{:>5}"), "OFF");
                break;
            case log_severity::trace:
                fmt::format_to(
                    std::back_inserter(dest), FMT_COMPILE("{:>5}"), "TRACE");
                break;
            case log_severity::debug:
                fmt::format_to(
                    std::back_inserter(dest), FMT_COMPILE("{:>5}"), "DEBUG");
                break;
            case log_severity::info:
                fmt::format_to(
                    std::back_inserter(dest), FMT_COMPILE("{:>5}"), "INFO");
                break;
            case log_severity::warn:
                fmt::format_to(
                    std::back_inserter(dest), FMT_COMPILE("{:>5}"), "WARN");
                break;
            case log_severity::error:
                fmt::format_to(
                    std::back_inserter(dest), FMT_COMPILE("{:>5}"), "ERROR");
                break;
            case log_severity::fatal:
                fmt::format_to(
                    std::back_inserter(dest), FMT_COMPILE("{:>5}"), "FATAL");
                break;
        }
        return dest;
    }

    static constexpr fmt::string_view trunc_file(const fmt::string_view& v)
    {
        fmt::string_view x{v};
        int count = 0;
        for (std::size_t i = 0; i < x.size(); ++i) {
            if (x[x.size() - i - 1] == '/'
#ifdef _WIN32
                || x[x.size() - i - 1] == '\\'
#endif
            ) {
                if (++count == 2) {
                    fmt::string_view ret{x.data() + x.size() - i, i};
                    return ret;
                }
            }
        }
        return x;
    }

    template <int N>
    static constexpr fmt::string_view to_view(const char (&str)[N])
    {
        return fmt::string_view{str, N - 1};
    }

    template <std::size_t SIZE>
    static constexpr fmt::string_view to_view(const buffer_t<SIZE>& buff)
    {
        return fmt::string_view{buff.data(), buff.size()};
    }

    template <std::size_t SIZE>
    static std::string to_string(const buffer_t<SIZE>& dest)
    {
        return fmt::to_string(dest);
    }
};

using log_buffer_t = buffer_t<1024>;

} // namespace ldgr

#endif /*INCLUDED_LDGR_FMTUTIL_HPP*/
