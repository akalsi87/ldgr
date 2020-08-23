//! @file logentry.cpp

#include <ldgr/logentry.hpp>

#include <ldgr/fmtutil.hpp>

#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include <catch2/catch.hpp>

using namespace ldgr;

TEST_CASE("logentry: basic")
{
    log_entry entry{log_severity::info,
                    fmtutil::to_view("LOG.CAT"),
                    fmtutil::to_view("src/foo/bar.hpp"),
                    fmtutil::to_view("123"),
                    time_point(std::chrono::microseconds(1598153679123456ll)),
                    fmtutil::to_view("Some message type")};
    REQUIRE(entry.when.time_since_epoch().count() == 1598153679123456000ll);
    SECTION("convert to log_entry_fmt gmt")
    {
        auto out = log_entry_util::to_log_entry_fmt(entry);
        REQUIRE(out.severity == entry.severity);
        REQUIRE(out.name == entry.name);
        REQUIRE(out.file == entry.file);
        REQUIRE(out.line == entry.line);
        REQUIRE(out.time_struct.tm_year == 120);
        REQUIRE(out.time_struct.tm_mon == 7);
        REQUIRE(out.time_struct.tm_mday == 23);
        REQUIRE(out.time_struct.tm_hour == 3);
        REQUIRE(out.time_struct.tm_min == 34);
        REQUIRE(out.time_struct.tm_sec == 39);
        REQUIRE(out.microseconds == 123456);
        REQUIRE(out.is_local == false);
        REQUIRE(out.message == entry.message);
    }
    SECTION("convert to log_entry_fmt local")
    {
        auto out = log_entry_util::to_log_entry_fmt(entry, true);
        REQUIRE(out.severity == entry.severity);
        REQUIRE(out.name == entry.name);
        REQUIRE(out.file == entry.file);
        REQUIRE(out.line == entry.line);
        REQUIRE(out.time_struct.tm_year == 120);
        REQUIRE(out.time_struct.tm_mon == 7);
        REQUIRE(out.time_struct.tm_mday == 22);
        REQUIRE(out.time_struct.tm_hour == 23);
        REQUIRE(out.time_struct.tm_min == 34);
        REQUIRE(out.time_struct.tm_sec == 39);
        REQUIRE(out.microseconds == 123456);
        REQUIRE(out.is_local == true);
        REQUIRE(out.message == entry.message);
    }
    SECTION("convert to log_entry_fmt_cp")
    {
        auto data = log_entry_util::copy_log_entry(entry);
        const auto& out = data.entry;
        REQUIRE(out.severity == entry.severity);
        REQUIRE(out.name == entry.name);
        REQUIRE(out.file == entry.file);
        REQUIRE(out.line == entry.line);
        REQUIRE(out.time_struct.tm_year == 120);
        REQUIRE(out.time_struct.tm_mon == 7);
        REQUIRE(out.time_struct.tm_mday == 23);
        REQUIRE(out.time_struct.tm_hour == 3);
        REQUIRE(out.time_struct.tm_min == 34);
        REQUIRE(out.time_struct.tm_sec == 39);
        REQUIRE(out.microseconds == 123456);
        REQUIRE(out.is_local == false);
        REQUIRE(out.message == entry.message);
        REQUIRE(out.name.begin() != entry.name.begin());
        REQUIRE(out.file.begin() != entry.file.begin());
        REQUIRE(out.line.begin() != entry.line.begin());
        REQUIRE(out.message.begin() != entry.message.begin());
    }
    SECTION("convert to log_entry_fmt_cp pooled factory")
    {
        auto pooled_fact = pooled_log_buffer_factory::create();
        auto& factory = *pooled_fact;
        auto data = log_entry_util::copy_log_entry(entry, false, factory);
        const auto& out = data.entry;
        auto* buff = data.buffer.get();
        REQUIRE(out.severity == entry.severity);
        REQUIRE(out.name == entry.name);
        REQUIRE(out.file == entry.file);
        REQUIRE(out.line == entry.line);
        REQUIRE(out.time_struct.tm_year == 120);
        REQUIRE(out.time_struct.tm_mon == 7);
        REQUIRE(out.time_struct.tm_mday == 23);
        REQUIRE(out.time_struct.tm_hour == 3);
        REQUIRE(out.time_struct.tm_min == 34);
        REQUIRE(out.time_struct.tm_sec == 39);
        REQUIRE(out.microseconds == 123456);
        REQUIRE(out.is_local == false);
        REQUIRE(out.message == entry.message);
        REQUIRE(out.name.begin() != entry.name.begin());
        REQUIRE(out.file.begin() != entry.file.begin());
        REQUIRE(out.line.begin() != entry.line.begin());
        REQUIRE(out.message.begin() != entry.message.begin());
        data.buffer.reset();
        data = log_entry_util::copy_log_entry(entry, false, factory);
        REQUIRE(data.buffer.get() == buff);
    }
    SECTION("benchmarks")
    {
        auto pooled_fact = pooled_log_buffer_factory::create();
        auto& factory = *pooled_fact;
        BENCHMARK("copying entries default")
        {
            auto out = log_entry_util::copy_log_entry(entry, false);
        };
        BENCHMARK("copying entries pooled")
        {
            auto out = log_entry_util::copy_log_entry(entry, false, factory);
        };
        BENCHMARK("default factory")
        {
            default_log_buffer_factory()();
        };
        BENCHMARK("pooled factory")
        {
            factory();
        };
    }
}
