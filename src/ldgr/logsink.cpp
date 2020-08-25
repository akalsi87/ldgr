//! @file logsink.cpp

#include <ldgr/logsink.hpp>

#include <cstdio>

namespace ldgr {

log_sink::~log_sink() = default;

struct file_sink final : public log_sink {
    std::FILE* d_file_{nullptr};
    mutable std::mutex d_write_mutex_{};

    explicit file_sink(std::FILE* f): d_file_(f), d_write_mutex_()
    {
    }

    ~file_sink()
    {
        if (d_file_ != stdout && d_file_ != stderr) {
            std::fclose(d_file_);
        }
    }

    void do_log(const log_buffer_t& buff) override
    {
        std::lock_guard<std::mutex> guard{d_write_mutex_};
        std::fwrite(buff.data(), 1, buff.size(), d_file_);
        std::fflush(d_file_);
    }

    void do_flush() override
    {
        std::lock_guard<std::mutex> guard{d_write_mutex_};
        std::fflush(d_file_);
    }
};

std::shared_ptr<log_sink> log_sink_factory::stdout_sink()
{
    static std::shared_ptr<log_sink> s_err{
        std::make_shared<file_sink>(stdout)};
    return s_err;
}

std::shared_ptr<log_sink> log_sink_factory::stderr_sink()
{
    static std::shared_ptr<log_sink> s_err{
        std::make_shared<file_sink>(stderr)};
    return s_err;
}

} // namespace ldgr
