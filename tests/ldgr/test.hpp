//! \file test.hpp

#ifndef INCLUDED_TEST
#define INCLUDED_TEST

#include <cstddef>
#include <cstdint>
#include <functional>
#include <iostream>
#include <limits>
#include <optional>
#include <string>
#include <vector>

//! \class Foo
struct Foo {
    int id;
    std::string name;
    std::int64_t hash;
};

// FREE OPERATORS
bool operator==(const Foo& lhs, const Foo& rhs) noexcept;
bool operator!=(const Foo& lhs, const Foo& rhs) noexcept;
bool operator<(const Foo& lhs, const Foo& rhs) noexcept;
bool operator>(const Foo& lhs, const Foo& rhs) noexcept;
bool operator<=(const Foo& lhs, const Foo& rhs) noexcept;
bool operator>=(const Foo& lhs, const Foo& rhs) noexcept;
std::ostream& operator<<(std::ostream& os, const Foo& obj);
std::istream& fromJson(std::istream& is, Foo& obj);
std::ostream& toJson(std::ostream& os, const Foo& obj);

// IMPLEMENTATION
#ifndef INCLUDED_MSGGEN_IMPL_
#define INCLUDED_MSGGEN_IMPL_

namespace msggen {

inline std::size_t hashCombine(std::size_t a, std::size_t b)
{
    return ((a << 4) + a) + b; // result = a x 17 + b
}

template <class T>
struct H {
    std::size_t operator()(const T& v) const noexcept
    {
        return std::hash<T>()(v);
    }
};

template <class T>
struct H<std::vector<T>> {
    std::size_t operator()(const std::vector<T>& v) const noexcept
    {
        auto hasher = std::hash<T>();
        std::size_t h{0};
        for (const auto& item : v) {
            h = hashCombine(h, hasher(item));
        }
        h = hashCombine(h, v.size());
        return h;
    }
};

template <class T>
struct P {
    std::ostream& print(std::ostream& os, const T& v) const noexcept
    {
        return (os << v);
    }
};

template <class T>
struct P<std::optional<T>> {
    std::ostream& print(std::ostream& os, const std::optional<T>& v) const
        noexcept
    {
        if (!v.has_value()) {
            return (os << "null");
        }
        return P<T>().print(os, *v);
    }
};

template <class T>
struct P<std::vector<T>> {
    std::ostream& print(std::ostream& os, const std::vector<T>& v) const
        noexcept
    {
        os.put('[');
        for (const auto& x : v) {
            P<T>().print(os.put(' '), x);
        }
        return (os << " ]");
    }
};

template <class T>
struct JW;

template <class T>
struct JW {
    static std::ostream& jsonWrite(std::ostream& os, const T& val)
    {
        if (!os) {
            return os;
        }
        return (os << val);
    }
};

template <>
struct JW<std::int8_t> {
    static std::ostream& jsonWrite(std::ostream& os, const std::int8_t& val)
    {
        if (!os) {
            return os;
        }
        return (os << static_cast<int>(val));
    }
};

template <>
struct JW<std::uint8_t> {
    static std::ostream& jsonWrite(std::ostream& os, const std::uint8_t& val)
    {
        if (!os) {
            return os;
        }
        return (os << static_cast<unsigned int>(val));
    }
};

template <>
struct JW<std::string> {
    static std::ostream& jsonWrite(std::ostream& os, const std::string& val)
    {
        if (!os) {
            return os;
        }
        const char* s = val.c_str();
        char ch;
        os.put('"');
        while ((ch = *(s++)) != 0) {
            switch (ch) {
                case '\b':
                    os.put('\\');
                    os.put('b');
                    continue;
                case '\t':
                    os.put('\\');
                    os.put('t');
                    continue;
                case '\f':
                    os.put('\\');
                    os.put('f');
                    continue;
                case '\n':
                    os.put('\\');
                    os.put('n');
                    continue;
                case '\r':
                    os.put('\\');
                    os.put('r');
                    continue;
                case '"':
                    os.put('\\');
                    os.put('"');
                    continue;
                case '\\':
                    os.put('\\');
                    os.put('\\');
                    continue;
                default: os.put(ch); continue;
            }
            if (!os) {
                return os;
            }
        }
        os.put('"');
        return os;
    }
};

template <>
struct JW<bool> {
    static std::ostream& jsonWrite(std::ostream& os, const bool& val)
    {
        if (!os) {
            return os;
        }
        const char* values[] = {"false", "true"};
        auto asInt = static_cast<int>(val);
        return os.write(values[asInt], 5 - asInt);
    }
};

template <>
struct JW<float> {
    static std::ostream& jsonWrite(std::ostream& os, const float& val)
    {
        if (!os) {
            return os;
        }
        auto currPrecision = os.precision();
        os.precision(9);
        os << val;
        os.precision(currPrecision);
        return os;
    }
};

template <>
struct JW<double> {
    static std::ostream& jsonWrite(std::ostream& os, const double& val)
    {
        if (!os) {
            return os;
        }
        auto currPrecision = os.precision();
        os.precision(18);
        os << val;
        os.precision(currPrecision);
        return os;
    }
};

template <class T>
struct JW<std::optional<T>> {
    static std::ostream& jsonWrite(std::ostream& os,
                                   const std::optional<T>& val)
    {
        if (!os) {
            return os;
        }
        if (!val.has_value()) {
            return (os << "null");
        }
        return JW<T>::jsonWrite(os, *val);
    }
};

template <class T>
struct JW<std::vector<T>> {
    static std::ostream& jsonWrite(std::ostream& os, const std::vector<T>& val)
    {
        if (!os) {
            return os;
        }
        os.put('[');
        if (!val.empty()) {
            auto it = val.begin();
            const auto last = val.end() - 1;
            for (; it < last; ++it) {
                if (!os) {
                    return os;
                }
                JW<T>::jsonWrite(os, *it);
                os.put(',');
            }
            JW<T>::jsonWrite(os, *it);
        }
        return os.put(']');
    }
};

inline std::istream& jsonSkipWs(std::istream& is)
{
    bool cont = true;
    while (cont && is) {
        switch (is.peek()) {
            case ' ':
            case '\t':
            case '\n':
            case '\r': {
                is.get();
                continue;
            }
            default: {
                cont = false;
            } break;
        }
    }
    return is;
}

template <class T, class U>
static bool jsonInRange(const U& v) noexcept
{
    return v >= std::numeric_limits<T>::min() &&
           v <= std::numeric_limits<T>::max();
}

template <class T>
struct JR;

template <class T>
struct JR {
    static std::istream& jsonRead(std::istream& is, T& val)
    {
        if (!is) {
            return is;
        }
        return (is >> val);
    }
};

template <>
struct JR<std::int8_t> {
    static std::istream& jsonRead(std::istream& is, std::int8_t& val)
    {
        if (!is) {
            return is;
        }
        int value;
        if (is >> value) {
            if (jsonInRange<std::int8_t>(value)) {
                val = value;
            }
            else {
                is.setstate(std::ios_base::failbit);
            }
        }
        return is;
    }
};

template <>
struct JR<std::uint8_t> {
    static std::istream& jsonRead(std::istream& is, std::uint8_t& val)
    {
        if (!is) {
            return is;
        }
        unsigned int value;
        if (is >> value) {
            if (jsonInRange<std::uint8_t>(value)) {
                val = value;
            }
            else {
                is.setstate(std::ios_base::failbit);
            }
        }
        return is;
    }
};

template <>
struct JR<bool> {
    static std::istream& jsonRead(std::istream& is, bool& val)
    {
        bool fail = true;
        jsonSkipWs(is);
        switch (is.get()) {
            case 't': {
                fail =
                    !(is.get() == 'r' && is.get() == 'u' && is.get() == 'e');
                val = true;
            } break;
            case 'f': {
                fail = !(is.get() == 'a' && is.get() == 'l' &&
                         is.get() == 's' && is.get() == 'e');
                val = false;
            } break;
            default: break;
        }
        if (fail) {
            is.setstate(std::ios_base::failbit);
        }
        return is;
    }
};

template <>
struct JR<std::string> {
    static std::istream& jsonRead(std::istream& is, std::string& s)
    {
        char ch;
        s.clear();
        jsonSkipWs(is);
        if (is.get() != '"') {
            is.setstate(std::ios_base::failbit);
            return is;
        }
        while ((ch = is.get()) != '"') {
            if (ch == '\\') {
                switch (is.get()) {
                    case 'b': s.push_back('\b'); continue;
                    case 't': s.push_back('\t'); continue;
                    case 'f': s.push_back('\f'); continue;
                    case 'n': s.push_back('\n'); continue;
                    case 'r': s.push_back('\r'); continue;
                    case '"': s.push_back('"'); continue;
                    case '\\': s.push_back('\\'); continue;
                    default: is.setstate(std::ios_base::failbit); return is;
                }
            }
            else {
                s.push_back(ch);
            }
        }
        return is;
    }
};

template <class T>
struct JR<std::optional<T>> {
    static std::istream& jsonRead(std::istream& is, std::optional<T>& val)
    {
        if (!is) {
            return is;
        }
        val.reset();
        bool fail = true;
        jsonSkipWs(is);
        if (is.peek() == 'n') {
            is.get();
            if (is.get() == 'u' && is.get() == 'l' && is.get() == 'l') {
                fail = false;
                val.reset();
            }
        }
        else {
            T obj;
            if (JR<T>::jsonRead(is, obj)) {
                fail = false;
                val = std::move(obj);
            }
        }
        if (fail) {
            is.setstate(std::ios_base::failbit);
        }
        return is;
    }
};

template <class T>
struct JR<std::vector<T>> {
    static std::istream& jsonRead(std::istream& is, std::vector<T>& val)
    {
        if (!is) {
            return is;
        }
        val.clear();
        jsonSkipWs(is);
        if (is.get() != '[') {
            is.setstate(std::ios_base::failbit);
            return is;
        }
        jsonSkipWs(is);
        if (is.peek() == ']') {
            is.get();
            return is;
        }
        while (true) {
            val.emplace_back();
            if (!JR<T>::jsonRead(is, val.back())) {
                return is;
            }
            jsonSkipWs(is);
            if (is.peek() == ',') {
                is.get();
                jsonSkipWs(is);
            }
            else if (is.peek() == ']') {
                is.get();
                break;
            }
            else {
                is.setstate(std::ios_base::failbit);
                return is;
            }
        }
        return is;
    }
};

template <class T>
void destroy(T& v) noexcept
{
    v.~T();
}

} // namespace msggen

template <class T>
std::ostream& toJson(std::ostream& os, const T& val)
{
    return msggen::JW<T>::jsonWrite(os, val);
}

template <class T>
std::istream& fromJson(std::istream& is, T& val)
{
    return msggen::JR<T>::jsonRead(is, val);
}

#endif // INCLUDED_MSGGEN_IMPL_

// SEQUENCE: Foo
// FREE OPERATORS
inline bool operator==(const Foo& lhs, const Foo& rhs) noexcept
{
    return lhs.id == rhs.id && lhs.name == rhs.name && lhs.hash == rhs.hash;
}

inline bool operator!=(const Foo& lhs, const Foo& rhs) noexcept
{
    return !(lhs == rhs);
}

inline bool operator<(const Foo& lhs, const Foo& rhs) noexcept
{
    return lhs.id < rhs.id ||
           (lhs.id == rhs.id &&
            (lhs.name < rhs.name ||
             (lhs.name == rhs.name &&
              (lhs.hash < rhs.hash || (lhs.hash == rhs.hash && false)))));
}

inline bool operator>(const Foo& lhs, const Foo& rhs) noexcept
{
    return rhs < lhs;
}

inline bool operator<=(const Foo& lhs, const Foo& rhs) noexcept
{
    return !(rhs < lhs);
}

inline bool operator>=(const Foo& lhs, const Foo& rhs) noexcept
{
    return !(lhs < rhs);
}

inline std::ostream& operator<<(std::ostream& os, const Foo& obj)
{
    os << '[';
    os << " id=";
    msggen::P<int>().print(os, obj.id);
    os << " name=";
    msggen::P<std::string>().print(os, obj.name);
    os << " hash=";
    msggen::P<std::int64_t>().print(os, obj.hash);
    return (os << " ]");
}

inline std::istream& fromJson(std::istream& is, Foo& obj)
{
    msggen::jsonSkipWs(is);
    if (is.get() != '{') {
        is.setstate(std::ios_base::failbit);
        return is;
    }
    msggen::jsonSkipWs(is);
    std::string str;
    bool gotId = false;
    bool gotName = false;
    bool gotHash = false;
    ;
    while (is && is.peek() != '}') {
        if (!fromJson(is, str)) {
            return is;
        }
        msggen::jsonSkipWs(is);
        if (is.get() != ':') {
            is.setstate(std::ios_base::failbit);
            return is;
        }
        msggen::jsonSkipWs(is);
        if (str == "id") {
            if (gotId) {
                is.setstate(std::ios_base::failbit);
                return is;
            }
            gotId = true;
            if (!fromJson(is, obj.id)) {
                return is;
            }
            msggen::jsonSkipWs(is);
            if (is.peek() == ',') {
                is.get();
                msggen::jsonSkipWs(is);
            }
            continue;
        }
        if (str == "name") {
            if (gotName) {
                is.setstate(std::ios_base::failbit);
                return is;
            }
            gotName = true;
            if (!fromJson(is, obj.name)) {
                return is;
            }
            msggen::jsonSkipWs(is);
            if (is.peek() == ',') {
                is.get();
                msggen::jsonSkipWs(is);
            }
            continue;
        }
        if (str == "hash") {
            if (gotHash) {
                is.setstate(std::ios_base::failbit);
                return is;
            }
            gotHash = true;
            if (!fromJson(is, obj.hash)) {
                return is;
            }
            msggen::jsonSkipWs(is);
            if (is.peek() == ',') {
                is.get();
                msggen::jsonSkipWs(is);
            }
            continue;
        }
        is.setstate(std::ios_base::failbit);
        return is;
    }
    if (is.get() != '}' || !gotId || !gotName || !gotHash) {
        is.setstate(std::ios_base::failbit);
    }
    return is;
}

inline std::ostream& toJson(std::ostream& os, const Foo& obj)
{
    os.put('{');
    const char* out = "";
    os << out << "\"id\":";
    toJson(os, obj.id);
    out = ",";
    os << out << "\"name\":";
    toJson(os, obj.name);
    out = ",";
    os << out << "\"hash\":";
    toJson(os, obj.hash);
    out = ",";
    os.put('}');
    return os;
}

namespace msggen {

template <>
struct JR<Foo> {
    static std::istream& jsonRead(std::istream& is, Foo& obj)
    {
        return fromJson(is, obj);
    }
};

template <>
struct JW<Foo> {
    static std::ostream& jsonWrite(std::ostream& os, const Foo& obj)
    {
        return toJson(os, obj);
    }
};

} // namespace msggen

namespace std {

template <>
struct hash<Foo> {
    std::size_t operator()(const Foo& obj) const noexcept
    {
        std::size_t h{0};
        h = msggen::hashCombine(h, msggen::H<int>()(obj.id));
        h = msggen::hashCombine(h, msggen::H<std::string>()(obj.name));
        h = msggen::hashCombine(h, msggen::H<std::int64_t>()(obj.hash));
        return h;
    }
};

} // namespace std

#endif // INCLUDED_TEST
