//! @file logsink.cpp

#include <ldgr/logsink.hpp>

#include <cstdio>

namespace ldgr {

void default_formatter(log_buffer_t& buff,
                       const log_entry_fmt_cp& ent,
                       std::time_t& cached_time,
                       std::string& cached_str)
{
    const auto& e = ent.entry;

    if (e.time != cached_time) {
        fmtutil::append(buff, e.time_struct);
        cached_time = e.time;
        cached_str.assign(buff.begin(), buff.end());
    }
    else {
        fmtutil::append(buff, cached_str);
    }
    fmtutil::append(buff, '.');
    fmtutil::append_pad_int<6>(buff, e.microseconds);
    if (!e.is_local) {
        fmtutil::append(buff, 'Z');
    }
    fmtutil::append(buff, " [");
    fmtutil::append(buff, e.severity);
    fmtutil::append(buff, "] ");
    fmtutil::append(buff, e.name);
    fmtutil::append(buff, ' ');
    fmtutil::append(buff, fmtutil::trunc_file(e.file));
    fmtutil::append(buff, ':');
    fmtutil::append(buff, e.line);
    fmtutil::append(buff, ' ');
    fmtutil::append(buff, e.message);
    fmtutil::append_eol(buff);
}

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

std::shared_ptr<const log_formatter> log_sink::default_fmt()
{
    static const std::shared_ptr<const log_formatter> s_fmt{
        std::make_shared<log_formatter>(&default_formatter)};
    return s_fmt;
}

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
