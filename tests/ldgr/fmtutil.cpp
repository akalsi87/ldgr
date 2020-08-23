//! @file fmtutil.cpp

#include <ldgr/fmtutil.hpp>

#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include <catch2/catch.hpp>

#include <fmt/chrono.h>

using namespace ldgr;

TEST_CASE("fmtutil: basic")
{
    buffer_t<6> buff;
    SECTION("append_pad_int<2> 2")
    {
        REQUIRE(fmtutil::to_string(fmtutil::append_pad_int<2>(buff, 2)) ==
                "02");
    }
    SECTION("append_pad_int<2> 19")
    {
        REQUIRE(fmtutil::to_string(fmtutil::append_pad_int<2>(buff, 19)) ==
                "19");
    }
    SECTION("append_pad_int<4> 2")
    {
        REQUIRE(fmtutil::to_string(fmtutil::append_pad_int<4>(buff, 2)) ==
                "0002");
    }
    SECTION("append_pad_int<4> 19")
    {
        REQUIRE(fmtutil::to_string(fmtutil::append_pad_int<4>(buff, 19)) ==
                "0019");
    }
    SECTION("append_pad_int<4> 204")
    {
        REQUIRE(fmtutil::to_string(fmtutil::append_pad_int<4>(buff, 204)) ==
                "0204");
    }
    SECTION("append_pad_int<4> 1987")
    {
        REQUIRE(fmtutil::to_string(fmtutil::append_pad_int<4>(buff, 1987)) ==
                "1987");
    }
    SECTION("append tm")
    {
        std::tm val{};
        val.tm_year = 120;
        val.tm_mon = 7;
        val.tm_mday = 22;
        val.tm_hour = 23;
        val.tm_min = 5;
        val.tm_sec = 42;
        REQUIRE(fmtutil::to_string(fmtutil::append(buff, val)) ==
                "2020-08-22 23:05:42");
    }
    SECTION("append duration")
    {
        auto tp = std::chrono::microseconds(1598153679123456ll);
        REQUIRE(fmtutil::to_string(fmtutil::append(buff, tp)) ==
                "2020-08-23 03:34:39.123456Z");
    }
    SECTION("append level default")
    {
        REQUIRE(fmtutil::to_string(fmtutil::append(
                    buff, ldgr::log_severity::off)) == "  OFF");
    }
    SECTION("append level fmt")
    {
        REQUIRE(fmtutil::to_string(fmtutil::append(
                    buff, ldgr::log_severity::off, "{}")) == "OFF");
    }
    SECTION("truncate file name - case 1")
    {
        constexpr auto v = fmtutil::to_view("x/y/z");
        constexpr auto trunc = fmtutil::trunc_file(v);
        REQUIRE(trunc == fmtutil::to_view("y/z"));
    }
    SECTION("truncate file name - case 2")
    {
        constexpr auto v = fmtutil::to_view("z");
        constexpr auto trunc = fmtutil::trunc_file(v);
        REQUIRE(trunc == fmtutil::to_view("z"));
    }
    SECTION("truncate file name - case 3")
    {
        constexpr auto v = fmtutil::to_view("a/b");
        constexpr auto trunc = fmtutil::trunc_file(v);
        REQUIRE(trunc == fmtutil::to_view("a/b"));
    }
    SECTION("truncate file name - case 4")
    {
        constexpr auto v = fmtutil::to_view("abcd");
        constexpr auto trunc = fmtutil::trunc_file(v);
        REQUIRE(trunc == fmtutil::to_view("abcd"));
    }
}
