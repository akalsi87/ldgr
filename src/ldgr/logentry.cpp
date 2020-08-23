//! @file logentry.cpp

#include <ldgr/logentry.hpp>

namespace ldgr {

pooled_log_buffer_factory::~pooled_log_buffer_factory() noexcept
{
    node* n = nullptr;
    mem_block* b = nullptr;
    {
        std::lock_guard<std::mutex> guard{d_free_list_mutex_};
        n = d_free_list_;
        d_free_list_ = nullptr;
    }
    {
        std::lock_guard<std::mutex> guard{d_free_ctrl_blocks_mutex_};
        b = d_free_ctrl_blocks_;
        d_free_ctrl_blocks_ = nullptr;
    }
    while (n) {
        auto* next = n->next;
        delete n;
        n = next;
    }
    while (b) {
        auto* next = b->next;
        ::operator delete(b);
        b = next;
    }
}

} // namespace ldgr
