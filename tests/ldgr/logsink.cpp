//! @file logsink.cpp

#include <ldgr/logsink.hpp>

#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include <catch2/catch.hpp>

using namespace ldgr;

struct string_sink final : public log_sink {
    std::string str;

    void do_log(const log_buffer_t& buff) override
    {
        str.append(buff.begin(), buff.end());
    }

    void do_flush() override
    {
    }
};

#define __SEV(x) ::ldgr::log_severity::x
#define __STR2(x) #x
#define __STR(x) __STR2(x)

#define LOG(cat, lvl, fmtstr, ...)                                            \
    do {                                                                      \
        ::ldgr::log_buffer_t buff;                                            \
        ::fmt::format_to(                                                     \
            ::std::back_inserter(buff), FMT_COMPILE(fmtstr), ##__VA_ARGS__);  \
        ::ldgr::log_entry entry{__SEV(lvl),                                   \
                                ::ldgr::fmtutil::to_view(cat),                \
                                ::ldgr::fmtutil::to_view(__FILE__),           \
                                ::ldgr::fmtutil::to_view(__STR(__LINE__)),    \
                                ::std::chrono::system_clock::now(),           \
                                ::ldgr::fmtutil::to_view(buff)};              \
        auto cp =                                                             \
            ::ldgr::log_entry_util::copy_log_entry(entry, true, factory);     \
        err_sink->log(cp);                                                    \
    } while (0);

TEST_CASE("logsink: basic")
{
    string_sink sink{};

    log_entry entry{log_severity::info,
                    fmtutil::to_view("LOG.CAT"),
                    fmtutil::to_view("abc/src/foo/bar.hpp"),
                    fmtutil::to_view("123"),
                    time_point(std::chrono::microseconds(1598153679123456ll)),
                    fmtutil::to_view("foo")};

    auto cp = log_entry_util::copy_log_entry(entry);

    // auto pooled_fact = pooled_log_buffer_factory::create();
    // auto& factory = *pooled_fact;

    SECTION("log into string, default formatter")
    {
        sink.log(cp);
        REQUIRE(fmtutil::to_view(sink.str) ==
                fmtutil::to_view("2020-08-23 03:34:39.123456Z [ INFO] LOG.CAT "
                                 "src/foo/bar.hpp:123 foo\n"));
    }
    // SECTION("bench it!")
    // {
    // BENCHMARK("default fmt")
    // {
    //     sink.str.clear();
    //     sink.log(cp);
    // };
    // sink.set_formatter(std::make_shared<log_formatter>(
    //     [](log_buffer_t& buff, const log_entry_fmt_cp& ent) {
    //         const auto& e = ent.entry;
    //         fmtutil::append(buff, e.time_struct);
    //         fmtutil::append(buff, '.');
    //         fmtutil::append_pad_int<6>(buff, e.microseconds);
    //         if (!e.is_local) {
    //             fmtutil::append(buff, 'Z');
    //         }
    //         fmt::format_to(std::back_inserter(buff),
    //                        FMT_COMPILE(" [{:>5}] {} {}:{} {}\n"),
    //                        fmtutil::to_view(e.severity),
    //                        e.name,
    //                        fmtutil::trunc_file(e.file),
    //                        e.line,
    //                        e.message);
    //     }));
    // sink.str.clear();
    // sink.log(cp);
    // REQUIRE(fmtutil::to_view(sink.str) ==
    //         fmtutil::to_view("2020-08-23 03:34:39.123456Z [ INFO]
    //                          LOG.CAT "
    //                                  "foo/bar.hpp:123 foo\n"));
    // BENCHMARK("using fmt_compile")
    // {
    //     sink.str.clear();
    //     sink.log(cp);
    // };
    // }
    // SECTION("bench it! - stderr sink")
    // {
    //     auto err_sink = log_sink_factory::stderr_sink();
    //     BENCHMARK("stderr sink")
    //     {
    //         err_sink->log(cp);
    //     };
    // }
    // SECTION("bench it! - stderr sink")
    // {
    //     auto err_sink = log_sink_factory::stderr_sink();
    //     BENCHMARK("stderr sink")
    //     {
    //         LOG("MY.CAT", info, "foo");
    //     };
    // }
}
