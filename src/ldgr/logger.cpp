//! @file logger.cpp

#include <ldgr/logger.hpp>

namespace ldgr {

log_registry& log_registry::instance()
{
    static log_registry f;
    return f;
}

} // namespace ldgr
