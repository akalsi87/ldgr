//! @file logger.cpp

#include <ldgr/logger.hpp>
#include <ldgr/logseverity.hpp>

#include "test.hpp"

#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include <catch2/catch.hpp>

TEST_CASE("logger: bench")
{
    SECTION("info log")
    {
        BENCHMARK("perf")
        {
            LDGR_INFO("foo: value={}", 42);
        };
        BENCHMARK("perf - cat")
        {
            LDGR_CAT_INFO("MY.CAT", "foo: value={}", 42);
        };

        ldgr::log_registry::get("MY.CAT").set_level(ldgr::log_severity::off);
        BENCHMARK("perf - cat - off")
        {
            LDGR_CAT_INFO("MY.CAT", "foo: value={}", 42);
        };
        ldgr::log_registry::get("MY.CAT").set_level(ldgr::log_severity::info);

        BENCHMARK("perf - cat - on + custom type")
        {
            LDGR_CAT_INFO("MY.CAT", "foo: value={}", Foo{});
        };
    }
}
