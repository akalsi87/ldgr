"""
msggen


PURPOSE: Generate C++ value semantic types from Python-esque type descriptions
"""


import argparse
import ast
import itertools as it
from pathlib import Path
from typing import List, NamedTuple, Optional, Union


_allowed_scalar_types = (int, float, str, bool)

_allowed_scalar_type_names = list(
    cls.__name__ for cls in _allowed_scalar_types
)
_allowed_scalar_type_names.extend(
    f'{x}{y}' for x, y in it.product(('u', 'i'), [8, 16, 32, 64])
)
_allowed_scalar_type_names.extend(['f32', 'f64'])

_primitive_scalar_type_names = list(_allowed_scalar_type_names)
_primitive_scalar_type_names.remove('str')

_scalar_type_map = {
    'int': 'int',
    'float': 'double',
    'str': 'std::string',
    'bool': 'bool',
    'u8': 'std::uint8_t',
    'u16': 'std::uint16_t',
    'u32': 'std::uint32_t',
    'u64': 'std::uint64_t',
    'i8': 'std::int8_t',
    'i16': 'std::int16_t',
    'i32': 'std::int32_t',
    'i64': 'std::int64_t',
    'f32': 'float',
    'f64': 'double',
}


class Enumerator(NamedTuple):
    name: str
    value: int

    def validate(self):
        pass


class Field(NamedTuple):
    name: str
    type_name: str
    is_optional: bool = False
    is_list: bool = False
    default_value: Optional[Union[int, str, float, bool]] = None

    def validate(self):
        if self.is_optional and self.is_list:
            raise Error(
                f'Cannot be both optional and list: field name {self.name}'
            )
        default = self.default_value
        if (
            default
            and default.__class__.__name__ != self.type_name
            and (
                default.__class__.__name__ != 'int'
                or self.type_name not in _primitive_scalar_type_names
            )
        ):
            raise Error(
                f'Default value for field {self.name} of type '
                f'{self.type_name} is of type '
                f'{self.default_value.__class__.__name__}'
            )


class TypeDef(NamedTuple):
    name: str
    kind: str
    members: List[Union[Enumerator, Field]]
    doc: str = ''

    def validate(self):
        seen_names = set()
        for m in self.members:
            if m.name in seen_names:
                raise Error(
                    f'Repeated member name \'{m.name}\' for type {self.name}'
                )
            seen_names.add(m.name)
            m.validate()


class Module(NamedTuple):
    types: List[TypeDef]
    doc: str = ''
    name: str = ''

    def validate(self):
        seen_names = set()
        for t in self.types:
            if t.name in seen_names:
                raise Error(f'Repeated type name: {t.name}')
            seen_names.add(t.name)
            t.validate()
        for nm in _allowed_scalar_type_names:
            seen_names.add(nm)
        for t in self.types:
            if t.kind != 'enum':
                for f in t.members:
                    if f.type_name not in seen_names:
                        raise Error(
                            f'Type {t.name} field {f.name} references type '
                            f'\'{f.type_name}\' which is not found in the '
                            f'module'
                        )


class Error(Exception):
    """
    Message generation errors.
    """


def _parse_ast(src: str, filename: str = '<unknown>') -> ast.AST:
    return ast.parse(src)


def _node_to_enumerator(node: ast.AST) -> Enumerator:
    if not isinstance(node.value, ast.Constant) or not isinstance(
        node.value.value, int
    ):
        raise Error(
            f'Expected a constant integer value assignment: '
            f'line {node.lineno} column {node.col_offset}'
        )
    return Enumerator(name=node.targets[0].id, value=node.value.value)


def _is_comment(node: ast.AST) -> bool:
    out = (
        isinstance(node, ast.Expr)
        and isinstance(node.value, ast.Constant)
        and isinstance(node.value.value, str)
    )
    if out:
        # print(
        #     'Found comment:',
        #     ast.dump(node, True, True),
        # )
        pass
    return out


def _get_doc(node: ast.AST) -> str:
    return ast.get_docstring(node, clean=True) or ''


def _type_name(anno: ast.AST) -> str:
    if isinstance(anno, ast.Subscript) and anno.value.id in (
        'List',
        'Optional',
    ):
        anno = anno.slice.value
    if not isinstance(anno, ast.Name) and (
        not isinstance(anno, ast.Constant) or not isinstance(anno.value, str)
    ):
        raise Error(
            f'Expected a type annotation type name to be an identifier or '
            f'string: '
            f'line {anno.lineno} column {anno.col_offset}'
        )
    return anno.id if isinstance(anno, ast.Name) else anno.value


def _node_to_field(node: ast.AST) -> Field:
    anno = node.annotation
    if anno is None:
        raise Error(
            f'Expected a type annotation: '
            f'line {node.lineno} column {node.col_offset}'
        )

    out_dict = {
        'name': node.target.id,
        'type_name': '',
        'is_optional': False,
        'is_list': False,
        'default_value': None,
    }
    default = node.value
    if default and issubclass(
        type(getattr(default, 'value', None)), _allowed_scalar_types
    ):
        if type(default.value).__name__ not in _allowed_scalar_type_names:
            raise Error(
                f'Default values are allowed only for types '
                f'{_allowed_scalar_type_names}: '
                f'line {node.lineno} column {node.col_offset}'
            )
        out_dict['default_value'] = node.value.value

    if isinstance(anno, ast.Name):
        out_dict['type_name'] = _type_name(anno)
    elif isinstance(anno, ast.Constant) and isinstance(anno.value, str):
        out_dict['type_name'] = anno.value
    elif isinstance(anno, ast.Subscript) and anno.value.id in (
        'List',
        'Optional',
    ):
        out_dict['type_name'] = _type_name(anno)
        if anno.value.id == 'Optional':
            out_dict['is_optional'] = True
        else:
            out_dict['is_list'] = True
    else:
        raise Error(
            f'Expected a type or an \'Optional\' or \'List\' subscript: '
            f'line {node.lineno} column {node.col_offset}'
        )

    if (
        default
        and isinstance(default, ast.List)
        and out_dict['is_list']
        and default.elts
    ):
        raise Error(
            f'List default values cannot have elements: '
            f'member name {out_dict["name"]} with type {out_dict["type_name"]}'
        )
    if default and out_dict['is_optional'] and default.value:
        raise Error(
            f'Optional values cannot have a non-null default value: '
            f'member name {out_dict["name"]} with type {out_dict["type_name"]}'
        )

    return Field(**out_dict)


def _node_to_type_def(node: ast.AST) -> TypeDef:
    out_dict = {
        'name': node.name,
        'kind': '',
        'members': [],
        'doc': _get_doc(node),
    }
    if len(node.bases) != 1 or node.bases[0].id not in (
        'Choice',
        'Enum',
        'Sequence',
    ):
        raise Error(
            f'Expected single base \'Choice\', \'Enum\', or \'Sequence\': '
            f'line {node.lineno} column {node.col_offset}'
        )
    if node.bases[0].id == 'Enum':
        out_dict['kind'] = 'enum'
        for item in node.body:
            if _is_comment(item):
                continue
            if not isinstance(item, ast.Assign):
                print(item)
                raise Error(
                    f'Expected field value assignment: '
                    f'line {item.lineno} column {item.col_offset}'
                )
            out_dict['members'].append(_node_to_enumerator(item))
    else:
        out_dict['kind'] = (
            'choice' if node.bases[0].id == 'Choice' else 'sequence'
        )
        for item in node.body:
            if _is_comment(item):
                continue
            if not isinstance(item, ast.AnnAssign):
                print(item)
                raise Error(
                    f'Expected field annotation description: '
                    f'line {item.lineno} column {item.col_offset}'
                )
            out_dict['members'].append(_node_to_field(item))
    return TypeDef(**out_dict)


def _node_to_module(root: ast.AST, name: str = '') -> Module:
    out = Module(types=[], doc=_get_doc(root), name=name)
    for t in root.body:
        if _is_comment(t):
            continue
        if not isinstance(t, ast.ClassDef):
            raise Error(
                f'Expected a class definition: '
                f'line {t.lineno} column {t.col_offset}'
            )
        out.types.append(_node_to_type_def(t))
    return out


# main


def _opt_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description='msggen: C++ message type generator'
    )
    sp = parser.add_subparsers(help='', dest='cmd', required=True)
    grp = sp.add_parser('parse')
    grp.add_argument(
        '--file',
        help='Message file name to parse',
        type=argparse.FileType('r'),
        required=True,
    )
    grp = sp.add_parser('gencpp')
    grp.add_argument(
        '--file',
        help='Message file name to parse',
        type=argparse.FileType('r'),
        required=True,
    )
    grp.add_argument(
        '--out-dir',
        help='Output directory to place generated header',
        default='.',
    )
    # grp.add_argument(
    #     '--out-dir-src',
    #     help='Output directory to place generated source',
    #     default='.',
    # )
    grp.add_argument('--namespace', help='Namespace to generate code in')
    grp = sp.add_parser('test')
    return parser


def _topo_sort(types: List[TypeDef]) -> List[TypeDef]:
    out = []
    tmap = {t.name: t for t in types}
    seen = {t.name: 0 for t in types}

    def visit(t) -> None:
        seen[t.name] = 1
        mem = list(t.members)
        for idx, m in enumerate(t.members):
            if not isinstance(m, Field):
                continue
            if m.type_name in tmap:
                nt = tmap[m.type_name]
                if seen[nt.name] == 0:
                    # new type
                    visit(nt)
                if seen[nt.name] == 2:
                    # visited type
                    continue
                # cycle
                print(
                    f'/* WARNING: Type cycle:\n'
                    f' * {[t for t in seen.keys() if seen[t] == 1]},\n'
                    f' * at member {m.name} of type {m.type_name} */'
                )
                if not m.is_optional and not m.is_list:
                    dct = m._asdict()
                    dct.update({'is_optional': True})
                    mem[idx] = Field(**dct)
                seen[nt.name] = 2
                continue

        seen[t.name] = 2
        out.append(TypeDef(name=t.name, members=mem, doc=t.doc, kind=t.kind))

    for t in types:
        if seen[t.name] == 0:
            visit(t)
    return out


def _gen_field(m: Field) -> str:
    tn = (
        _scalar_type_map[m.type_name]
        if m.type_name in _scalar_type_map
        else m.type_name
    )
    type_name = (
        f'std::optional<{tn}>'
        if m.is_optional
        else f'std::vector<{tn}>'
        if m.is_list
        else tn
    )
    return (
        f'{type_name} {m.name}'
        f'{f" = {m.default_value}" if m.default_value else ""}'
    )


def _generate_hdr(mod: Module, ns: str, out_dir: str) -> None:
    has_lists = any(
        isinstance(f, Field) and f.is_list
        for f in it.chain(*map(lambda x: x.members, mod.types))
    )
    has_optionals = any(
        isinstance(f, Field) and f.is_optional
        for f in it.chain(*map(lambda x: x.members, mod.types))
    )
    has_strs = any(
        isinstance(f, Field) and f.type_name == 'str'
        for f in it.chain(*map(lambda x: x.members, mod.types))
    )
    only_enums = all(t.kind == 'enum' for t in mod.types)

    modname = mod.name
    modnameup = modname.upper()
    modnamelw = modname.lower()
    import io

    stream = io.StringIO()

    bs = '\\'
    nl = '\n'
    stream.write(
        f'''//! {bs}file {modname}.hpp
{f"//! {bs}brief {mod.doc}" if mod.doc else ""}

#ifndef INCLUDED_{modnameup}
#define INCLUDED_{modnameup}

'''
    )

    stream.write('#include <cstddef>\n')
    stream.write('#include <cstdint>\n')
    stream.write('#include <functional>\n')
    stream.write('#include <iostream>\n')
    stream.write('#include <limits>\n')
    stream.write('#include <optional>\n')
    stream.write('#include <string>\n')
    stream.write('#include <vector>\n')
    stream.write(f'\nnamespace {ns} {{\n' if ns else '')

    for t in mod.types:
        if t.kind == 'enum':
            continue
        for m in t.members:
            if (m.is_optional or m.is_list) and m.type_name == t.name:
                raise Error(
                    f'Cannot use incomplete type in optional or list fields: '
                    f'field {m.name} with type {t.name}'
                )

    # guts beg
    for t in mod.types:
        if t.kind == 'enum':
            _gen_enum_def_method_decl(bs, nl, stream, t)
        elif t.kind == 'sequence':
            _gen_sequence_def_method_decl(bs, nl, stream, t)
        elif t.kind == 'choice':
            _gen_choice_def_method_decl(bs, nl, stream, t)
    stream.write('\n// IMPLEMENTATION\n')
    _gen_impl_common(ns, bs, nl, stream, only_enums)
    nsq = f'{ns}::' if ns else ''
    for t in mod.types:
        if t.kind == 'enum':
            _gen_enum_method_def(nsq, bs, nl, stream, t)
        elif t.kind == 'sequence':
            _gen_sequence_method_def(nsq, bs, nl, stream, t)
        elif t.kind == 'choice':
            _gen_choice_method_def(nsq, bs, nl, stream, t)
    # guts end
    stream.write(f'{f"{nl}}} // namespace {ns}{nl}" if ns else ""}{nl}')
    nsq = f'{ns}::' if ns else ''
    for t in mod.types:
        if t.kind != 'enum':
            _gen_hash(nsq, stream, t)

    stream.write(f'#endif // INCLUDED_{modnameup}{nl}')

    import sys
    from pathlib import Path
    from tempfile import TemporaryDirectory

    with TemporaryDirectory() as dir:
        out = stream.getvalue()
        outpath = Path(out_dir) / f'{mod.name}.hpp'
        if outpath.exists() and outpath.read_text() == out:
            print(
                'Output file already exists and is up to date', file=sys.stderr
            )
            return
        outpath.parent.mkdir(exist_ok=True, parents=True)
        outpath.write_text(out)


def _gen_impl_common(ns, bs, nl, stream, only_enums):
    stream.write(
        f'''\
#ifndef INCLUDED_MSGGEN_IMPL_{ns.upper()}
#define INCLUDED_MSGGEN_IMPL_{ns.upper()}

namespace msggen {{

inline std::size_t hashCombine(std::size_t a, std::size_t b)
{{
    return ((a << 4) + a) + b;  // result = a x 17 + b
}}

template <class T>
struct H {{
    std::size_t operator()(const T& v) const noexcept
    {{
        return std::hash<T>()(v);
    }}
}};

template <class T>
struct H<std::vector<T>> {{
    std::size_t operator()(const std::vector<T>& v) const noexcept
    {{
        auto hasher = std::hash<T>();
        std::size_t h{{0}};
        for (const auto& item : v) {{
            h = hashCombine(h, hasher(item));
        }}
        h = hashCombine(h, v.size());
        return h;
    }}
}};

template <class T>
struct P {{
    std::ostream& print(std::ostream& os, const T& v) const noexcept
    {{
        return (os << v);
    }}
}};

template <class T>
struct P<std::optional<T>> {{
    std::ostream& print(std::ostream& os, const std::optional<T>& v) const noexcept
    {{
        if (!v.has_value()) {{
            return (os << "null");
        }}
        return P<T>().print(os, *v);
    }}
}};

template <class T>
struct P<std::vector<T>> {{
    std::ostream& print(std::ostream& os, const std::vector<T>& v) const noexcept
    {{
        os.put('[');
        for (const auto& x : v) {{
            P<T>().print(os.put(' '), x);
        }}
        return (os << " ]");
    }}
}};

template <class T>
struct JW;

template <class T>
struct JW {{
    static std::ostream& jsonWrite(std::ostream& os, const T& val)
    {{
        if (!os) {{
            return os;
        }}
        return (os << val);
    }}
}};

template <>
struct JW<std::int8_t> {{
    static std::ostream& jsonWrite(std::ostream& os, const std::int8_t& val)
    {{
        if (!os) {{
            return os;
        }}
        return (os << static_cast<int>(val));
    }}
}};

template <>
struct JW<std::uint8_t> {{
    static std::ostream& jsonWrite(std::ostream& os, const std::uint8_t& val)
    {{
        if (!os) {{
            return os;
        }}
        return (os << static_cast<unsigned int>(val));
    }}
}};

template <>
struct JW<std::string> {{
    static std::ostream& jsonWrite(std::ostream& os, const std::string& val)
    {{
        if (!os) {{
            return os;
        }}
        const char* s = val.c_str();
        char ch;
        os.put('"');
        while ((ch = *(s++)) != 0) {{
            switch (ch) {{
                case '{bs}b':
                    os.put('{bs}{bs}');
                    os.put('b');
                    continue;
                case '{bs}t':
                    os.put('{bs}{bs}');
                    os.put('t');
                    continue;
                case '{bs}f':
                    os.put('{bs}{bs}');
                    os.put('f');
                    continue;
                case '{bs}n':
                    os.put('{bs}{bs}');
                    os.put('n');
                    continue;
                case '{bs}r':
                    os.put('{bs}{bs}');
                    os.put('r');
                    continue;
                case '"':
                    os.put('{bs}{bs}');
                    os.put('"');
                    continue;
                case '{bs}{bs}':
                    os.put('{bs}{bs}');
                    os.put('{bs}{bs}');
                    continue;
                default: os.put(ch); continue;
            }}
            if (!os) {{
                return os;
            }}
        }}
        os.put('"');
        return os;
    }}
}};

template <>
struct JW<bool> {{
    static std::ostream& jsonWrite(std::ostream& os, const bool& val)
    {{
        if (!os) {{
            return os;
        }}
        const char* values[] = {{"false", "true"}};
        auto asInt = static_cast<int>(val);
        return os.write(values[asInt], 5 - asInt);
    }}
}};

template <>
struct JW<float> {{
    static std::ostream& jsonWrite(std::ostream& os, const float& val)
    {{
        if (!os) {{
            return os;
        }}
        auto currPrecision = os.precision();
        os.precision(9);
        os << val;
        os.precision(currPrecision);
        return os;
    }}
}};

template <>
struct JW<double> {{
    static std::ostream& jsonWrite(std::ostream& os, const double& val)
    {{
        if (!os) {{
            return os;
        }}
        auto currPrecision = os.precision();
        os.precision(18);
        os << val;
        os.precision(currPrecision);
        return os;
    }}
}};

template <class T>
struct JW<std::optional<T>> {{
    static std::ostream& jsonWrite(std::ostream& os, const std::optional<T>& val)
    {{
        if (!os) {{
            return os;
        }}
        if (!val.has_value()) {{
            return (os << "null");
        }}
        return JW<T>::jsonWrite(os, *val);
    }}
}};

template <class T>
struct JW<std::vector<T>> {{
    static std::ostream& jsonWrite(std::ostream& os, const std::vector<T>& val)
    {{
        if (!os) {{
            return os;
        }}
        os.put('[');
        if (!val.empty()) {{
            auto it = val.begin();
            const auto last = val.end() - 1;
            for (; it < last; ++it) {{
                if (!os) {{
                    return os;
                }}
                JW<T>::jsonWrite(os, *it);
                os.put(',');
            }}
            JW<T>::jsonWrite(os, *it);
        }}
        return os.put(']');
    }}
}};

inline std::istream& jsonSkipWs(std::istream& is)
{{
    bool cont = true;
    while (cont && is) {{
        switch (is.peek()) {{
            case ' ':
            case '{bs}t':
            case '{bs}n':
            case '{bs}r': {{
                is.get();
                continue;
            }}
            default: {{
                cont = false;
            }} break;
        }}
    }}
    return is;
}}

template <class T, class U>
static bool jsonInRange(const U& v) noexcept
{{
    return v >= std::numeric_limits<T>::min() &&
           v <= std::numeric_limits<T>::max();
}}

template <class T>
struct JR;

template <class T>
struct JR {{
    static std::istream& jsonRead(std::istream& is, T& val)
    {{
        if (!is) {{
            return is;
        }}
        return (is >> val);
    }}
}};

template <>
struct JR<std::int8_t> {{
    static std::istream& jsonRead(std::istream& is, std::int8_t& val)
    {{
        if (!is) {{
            return is;
        }}
        int value;
        if (is >> value) {{
            if (jsonInRange<std::int8_t>(value)) {{
                val = value;
            }}
            else {{
                is.setstate(std::ios_base::failbit);
            }}
        }}
        return is;
    }}
}};

template <>
struct JR<std::uint8_t> {{
    static std::istream& jsonRead(std::istream& is, std::uint8_t& val)
    {{
        if (!is) {{
            return is;
        }}
        unsigned int value;
        if (is >> value) {{
            if (jsonInRange<std::uint8_t>(value)) {{
                val = value;
            }}
            else {{
                is.setstate(std::ios_base::failbit);
            }}
        }}
        return is;
    }}
}};

template <>
struct JR<bool> {{
    static std::istream& jsonRead(std::istream& is, bool& val)
    {{
        bool fail = true;
        jsonSkipWs(is);
        switch (is.get()) {{
            case 't': {{
                fail = !(is.get() == 'r' && is.get() == 'u' && is.get() == 'e');
                val = true;
            }} break;
            case 'f': {{
                fail = !(is.get() == 'a' && is.get() == 'l' && is.get() == 's' &&
                         is.get() == 'e');
                val = false;
            }} break;
            default: break;
        }}
        if (fail) {{
            is.setstate(std::ios_base::failbit);
        }}
        return is;
    }}
}};

template <>
struct JR<std::string> {{
    static std::istream& jsonRead(std::istream& is, std::string& s)
    {{
        char ch;
        s.clear();
        jsonSkipWs(is);
        if (is.get() != '"') {{
            is.setstate(std::ios_base::failbit);
            return is;
        }}
        while ((ch = is.get()) != '"') {{
            if (ch == '{bs}{bs}') {{
                switch (is.get()) {{
                    case 'b': s.push_back('{bs}b'); continue;
                    case 't': s.push_back('{bs}t'); continue;
                    case 'f': s.push_back('{bs}f'); continue;
                    case 'n': s.push_back('{bs}n'); continue;
                    case 'r': s.push_back('{bs}r'); continue;
                    case '"': s.push_back('"'); continue;
                    case '{bs}{bs}': s.push_back('{bs}{bs}'); continue;
                    default: is.setstate(std::ios_base::failbit); return is;
                }}
            }}
            else {{
                s.push_back(ch);
            }}
        }}
        return is;
    }}
}};

template <class T>
struct JR<std::optional<T>> {{
    static std::istream& jsonRead(std::istream& is, std::optional<T>& val)
    {{
        if (!is) {{
            return is;
        }}
        val.reset();
        bool fail = true;
        jsonSkipWs(is);
        if (is.peek() == 'n') {{
            is.get();
            if (is.get() == 'u' && is.get() == 'l' && is.get() == 'l') {{
                fail = false;
                val.reset();
            }}
        }}
        else {{
            T obj;
            if (JR<T>::jsonRead(is, obj)) {{
                fail = false;
                val = std::move(obj);
            }}
        }}
        if (fail) {{
            is.setstate(std::ios_base::failbit);
        }}
        return is;
    }}
}};

template <class T>
struct JR<std::vector<T>> {{
    static std::istream& jsonRead(std::istream& is, std::vector<T>& val)
    {{
        if (!is) {{
            return is;
        }}
        val.clear();
        jsonSkipWs(is);
        if (is.get() != '[') {{
            is.setstate(std::ios_base::failbit);
            return is;
        }}
        jsonSkipWs(is);
        if (is.peek() == ']') {{
            is.get();
            return is;
        }}
        while (true) {{
            val.emplace_back();
            if (!JR<T>::jsonRead(is, val.back())) {{
                return is;
            }}
            jsonSkipWs(is);
            if (is.peek() == ',') {{
                is.get();
                jsonSkipWs(is);
            }}
            else if (is.peek() == ']') {{
                is.get();
                break;
            }}
            else {{
                is.setstate(std::ios_base::failbit);
                return is;
            }}
        }}
        return is;
    }}
}};

template <class T>
void destroy(T& v) noexcept
{{
    v.~T();
}}

}} // namespace msggen

template <class T>
std::ostream& toJson(std::ostream& os, const T& val)
{{
    return msggen::JW<T>::jsonWrite(os, val);
}}

template <class T>
std::istream& fromJson(std::istream& is, T& val)
{{
    return msggen::JR<T>::jsonRead(is, val);
}}

#endif // INCLUDED_MSGGEN_IMPL_{ns.upper()}
'''
    )


def _gen_enum_method_def(nsq, bs, nl, stream, t):
    q = '"'
    stream.write(
        f'''
// ENUM: {t.name}
// FREE OPERATORS
inline std::ostream& operator<<(std::ostream& os, const {t.name}& obj)
{{
    switch (obj) {{
        {f"{nl}        ".join(f"case {t.name}::{m.name}: return (os << {q}{m.name}{q});" for idx, m in enumerate(t.members))}
    }}
    return (os << "<invalid-value>");
}}

inline std::istream& fromJson(std::istream& is, {t.name}& obj)
{{
    std::string str;
    if (!fromJson(is, str)) {{
        return is;
    }}
    {f"{nl}    ".join(f"if (str == {q}{m.name}{q}) {{ obj = {t.name}::{m.name}; return is; }}" for m in t.members)}
    is.setstate(std::ios_base::failbit);
    return is;
}}

inline std::ostream& toJson(std::ostream& os, const {t.name}& obj)
{{
    if (!os) {{
        return os;
    }}
    os.put('"');
    return (os << obj << '"');
}}

namespace msggen {{

template <>
struct JR<{t.name}> {{
    static std::istream& jsonRead(std::istream& is, {t.name}& obj)
    {{
        return fromJson(is, obj);
    }}
}};

template <>
struct JW<{t.name}> {{
    static std::ostream& jsonWrite(std::ostream& os, const {t.name}& obj)
    {{
        return toJson(os, obj);
    }}
}};

}} // namespace msggen
'''
    )


def _gen_sequence_method_def(nsq, bs, nl, stream, t):
    q = '"'

    def _gen_json_read(x: Field) -> str:
        return f'''if (str == {q}{x.name}{q}) {{
            if (got{x.name.capitalize()}) {{
                is.setstate(std::ios_base::failbit);
                return is;
            }}
            got{x.name.capitalize()} = true;
            if (!fromJson(is, obj.{x.name})) {{
                return is;
            }}
            msggen::jsonSkipWs(is);
            if (is.peek() == ',') {{
                is.get();
                msggen::jsonSkipWs(is);
            }}
            continue;
        }}'''

    def _gen_json_print(x: Field) -> str:
        return f'''\
os << " {x.name}=";
    msggen::P<{_cpp_type(nsq, x)}>().print(os, obj.{x.name});'''

    def _gen_json_write(m: Field) -> str:
        out = f'os << out << {q}{bs}{q}{m.name}{bs}{q}{":"}{q}; toJson(os, obj.{m.name}); out = ",";'
        if m.is_optional:
            tab = ' ' * 4
            return f'if (obj.{m.name}.has_value()) {{{nl}{tab * 2}{out}{nl}{tab}}}'
        return out

    stream.write(
        f'''
// SEQUENCE: {t.name}
// FREE OPERATORS
inline bool operator==(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return {f"{nl}        && ".join(f"lhs.{m.name} == rhs.{m.name}" for m in t.members)};
}}

inline bool operator!=(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return !(lhs == rhs);
}}

inline bool operator<(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return {f"{nl}        && (".join(f"lhs.{m.name} < rhs.{m.name} || (lhs.{m.name} == rhs.{m.name} " for m in t.members)}
           {"&& false" + ("))" * (len(t.members) - 1)) + ")"};
}}

inline bool operator>(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return rhs < lhs;
}}

inline bool operator<=(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return !(rhs < lhs);
}}

inline bool operator>=(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return !(lhs < rhs);
}}

inline std::ostream& operator<<(std::ostream& os, const {t.name}& obj)
{{
    os << '[';
    {f"{nl}    ".join(_gen_json_print(m) for m in t.members)}
    return (os << " ]");
}}

inline std::istream& fromJson(std::istream& is, {t.name}& obj)
{{
    msggen::jsonSkipWs(is);
    if (is.get() != '{{') {{
        is.setstate(std::ios_base::failbit);
        return is;
    }}
    msggen::jsonSkipWs(is);
    std::string str;
    {f"{nl}    ".join(f"bool got{x.name.capitalize()} = false;" for x in t.members)};
    while (is && is.peek() != '}}') {{
        if (!fromJson(is, str)) {{
            return is;
        }}
        msggen::jsonSkipWs(is);
        if (is.get() != ':') {{
            is.setstate(std::ios_base::failbit);
            return is;
        }}
        msggen::jsonSkipWs(is);
        {f"{nl}        ".join(_gen_json_read(x) for x in t.members)}
        is.setstate(std::ios_base::failbit);
        return is;
    }}
    if (is.get() != '}}'
         || {f"{nl}         || ".join(f"!got{x.name.capitalize()}" for x in t.members if not x.is_optional)}) {{
        is.setstate(std::ios_base::failbit);
    }}
    return is;
}}

inline std::ostream& toJson(std::ostream& os, const {t.name}& obj)
{{
    os.put('{{');
    const char* out = "";
    {f"{nl}    ".join(_gen_json_write(m) for m in t.members)}
    os.put('}}');
    return os;
}}

namespace msggen {{

template <>
struct JR<{t.name}> {{
    static std::istream& jsonRead(std::istream& is, {t.name}& obj)
    {{
        return fromJson(is, obj);
    }}
}};

template <>
struct JW<{t.name}> {{
    static std::ostream& jsonWrite(std::ostream& os, const {t.name}& obj)
    {{
        return toJson(os, obj);
    }}
}};

}} // namespace msggen
'''
    )


def _gen_choice_method_def(nsq, bs, nl, stream, t):
    q = '"'

    def _gen_json_read(idx: int, x: Field) -> str:
        return f'''if (str == {q}{x.name}{q}) {{
            obj.~{t.name}();
            obj.d_choice = {idx};
            ::new ((void*)&obj.{x.name}) {_cpp_type('', x)}();
            if (!fromJson(is, obj.{x.name})) {{
                obj = {t.name}();
                return is;
            }}
            msggen::jsonSkipWs(is);
            if (is.peek() == ',') {{
                is.setstate(std::ios_base::failbit);
                return is;
            }}
            break;
        }}'''

    def _gen_json_print(idx: int, x: Field) -> str:
        return f'''case {idx}: {{
            os << " {x.name} = ";
            msggen::P<{_cpp_type(nsq, x)}>().print(os, obj.{x.name});
        }} break;'''

    def _gen_dtor(idx: int, x: Field) -> str:
        if (
            x.type_name in _primitive_scalar_type_names
            and not x.is_optional
            and not x.is_list
        ):
            return f'/* type {_cpp_type("", x)} needs no destructor */'
        return f"case {idx}: msggen::destroy({x.name}); break;"

    stream.write(
        f'''
// CHOICE: {t.name}
// CREATORS
inline {t.name}::{t.name}() noexcept
: d_choice(0)
{{
    ::new ((void*)&{t.members[0].name}) {_cpp_type('', t.members[0])}();
}}

inline {t.name}::~{t.name}() noexcept
{{
    switch (d_choice) {{
        {f"{nl}        ".join(_gen_dtor(idx, m) for idx, m in enumerate(t.members))}
    }}
}}

inline {t.name}::{t.name}(const {t.name}& rhs)
: d_choice(rhs.d_choice)
{{
    switch (d_choice) {{
        {f"{nl}        ".join(f"case {idx}: ::new ((void*)&{m.name}) {_cpp_type('', m)}(rhs.{m.name}); break;" for idx, m in enumerate(t.members))}
    }}
}}

inline {t.name}::{t.name}({t.name}&& rhs) noexcept
: d_choice(rhs.d_choice)
{{
    switch(d_choice) {{
        {f"{nl}        ".join(f"case {idx}: ::new ((void*)&{m.name}) {_cpp_type('', m)}(std::move(rhs.{m.name})); break;" for idx, m in enumerate(t.members))}
    }}
}}

inline {t.name}& {t.name}::operator=(const {t.name}& rhs)
{{
    if (this == &rhs) {{
        return *this;
    }}
    this->~{t.name}();
    ::new ((void*)this) {t.name}(rhs);
    return *this;
}}

inline {t.name}& {t.name}::operator=({t.name}&& rhs) noexcept
{{
    if (this == &rhs) {{
        return *this;
    }}
    this->~{t.name}();
    ::new ((void*)this) {t.name}(std::move(rhs));
    return *this;
}}

// FREE OPERATORS
inline bool operator==(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    const auto choice = lhs.choice();
    if (choice != rhs.choice()) {{ return false; }}
    switch (choice) {{
        {f"{nl}        ".join(f"case {idx}: return lhs.{m.name} == rhs.{m.name};" for idx, m in enumerate(t.members))}
    }}
    return false;
}}

inline bool operator!=(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return !(lhs == rhs);
}}

inline bool operator<(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    const auto choice = rhs.choice();
    if (choice < rhs.choice()) {{ return true; }}
    if (choice > rhs.choice()) {{ return false; }}
    switch (choice) {{
        {f"{nl}        ".join(f"case {idx}: return lhs.{m.name} < rhs.{m.name};" for idx, m in enumerate(t.members))}
    }}
    return false;
}}

inline bool operator>(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return rhs < lhs;
}}

inline bool operator<=(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return !(rhs < lhs);
}}

inline bool operator>=(const {t.name}& lhs, const {t.name}& rhs) noexcept
{{
    return !(lhs < rhs);
}}

inline std::ostream& operator<<(std::ostream& os, const {t.name}& obj)
{{
    os << '[';
    switch (obj.choice()) {{
        {f"{nl}        ".join(_gen_json_print(idx, m) for idx, m in enumerate(t.members))}
    }}
    return (os << " ]");
}}

inline std::istream& fromJson(std::istream& is, {t.name}& obj)
{{
    msggen::jsonSkipWs(is);
    if (is.get() != '{{') {{
        is.setstate(std::ios_base::failbit);
        return is;
    }}
    msggen::jsonSkipWs(is);
    std::string str;
    while (is && is.peek() != '}}') {{
        if (!fromJson(is, str)) {{
            return is;
        }}
        msggen::jsonSkipWs(is);
        if (is.get() != ':') {{
            is.setstate(std::ios_base::failbit);
            return is;
        }}
        msggen::jsonSkipWs(is);
        {f"{nl}        ".join(_gen_json_read(idx, x) for idx, x in enumerate(t.members))}
        is.setstate(std::ios_base::failbit);
        return is;
    }}
    if (is.get() != '}}') {{
        is.setstate(std::ios_base::failbit);
    }}
    return is;
}}

inline std::ostream& toJson(std::ostream& os, const {t.name}& obj)
{{
    os.put('{{');
    switch (obj.choice()) {{
        {f"{nl}        ".join(f"case {idx}: {{ os << {q}{bs}{q}{m.name}{bs}{q}{':'}{q}; toJson(os, obj.{m.name}); }} break;" for idx, m in enumerate(t.members))}
    }}
    os.put('}}');
    return os;
}}

namespace msggen {{

template <>
struct JR<{t.name}> {{
    static std::istream& jsonRead(std::istream& is, {t.name}& obj)
    {{
        return fromJson(is, obj);
    }}
}};

template <>
struct JW<{t.name}> {{
    static std::ostream& jsonWrite(std::ostream& os, const {t.name}& obj)
    {{
        return toJson(os, obj);
    }}
}};

}} // namespace msggen
'''
    )


def _cpp_type(nsq: str, m: Field) -> str:
    tn = ''
    if m.type_name in _scalar_type_map:
        tn = _scalar_type_map[m.type_name]
    else:
        tn = f'{nsq}{m.type_name}'
    if m.is_optional:
        return f'std::optional<{tn}>'
    if m.is_list:
        return f'std::vector<{tn}>'
    return tn


def _gen_hash(nsq, stream, t):
    nl = '\n'
    tn = lambda m: _cpp_type(nsq, m)
    if t.kind == 'choice':
        stream.write(
            f'''namespace std {{

template <>
struct hash<{nsq}{t.name}> {{
    std::size_t operator()(const {nsq}{t.name}& obj) const noexcept
    {{
        std::size_t h{{0}};
        h = {nsq}msggen::hashCombine(h, obj.choice());
        switch (obj.choice()) {{
            {f"{nl}            ".join(f"case {idx}: h = {nsq}msggen::hashCombine(h, {nsq}msggen::H<{tn(m)}>()(obj.{m.name})); break;" for idx, m in enumerate(t.members))}
        }}
        return h;
    }}
}};

}} // namespace std

'''
        )
    elif t.kind == 'sequence':
        stream.write(
            f'''namespace std {{

template <>
struct hash<{nsq}{t.name}> {{
    std::size_t operator()(const {nsq}{t.name}& obj) const noexcept
    {{
        std::size_t h{{0}};
        {f"{nl}        ".join(f"h = {nsq}msggen::hashCombine(h, {nsq}msggen::H<{tn(m)}>()(obj.{m.name}));" for m in t.members)}
        return h;
    }}
}};

}} // namespace std

'''
        )


def _gen_choice_def_method_decl(bs, nl, stream, t):
    stream.write(
        f'''
//! {bs}class {t.name}{f'{f"{nl}//! {bs}brief {t.doc}" if t.doc else ""}'}
struct {t.name} {{
  private:
    int d_choice;
  public:
    union {{
        {f";{nl}        ".join(_gen_field(m) for m in t.members)};
    }};

    // CREATORS
    {t.name}() noexcept;

    ~{t.name}() noexcept;

    {t.name}(const {t.name}& rhs);

    {t.name}({t.name}&& rhs) noexcept;

    {t.name}& operator=(const {t.name}& rhs);

    {t.name}& operator=({t.name}&& rhs) noexcept;

    //! {bs}return The current field choice index (0-based).
    int choice() const {{ return d_choice; }}

    template <int IDX, class... ARGS>
    {t.name}& make(ARGS&&... args) noexcept
    {{
        static_assert(IDX >= 0 && IDX < {len(t.members)}, "Invalid index");
        this->~{t.name}();
        this->d_choice = IDX;
        try {{
            {f"{nl}            ".join(f"if constexpr(IDX == {idx}) {{ ::new ((void*)&{m.name}) {_cpp_type('', m)}(std::forward<ARGS>(args)...); }}" for idx, m in enumerate(t.members))}
        }}
        catch (...) {{
            ::new ((void*)this) {t.name}();
        }}
        return *this;
    }}

  private:
    friend std::istream& fromJson(std::istream& is, {t.name}& obj);
}};

// FREE OPERATORS
bool operator==(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator!=(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator<(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator>(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator<=(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator>=(const {t.name}& lhs, const {t.name}& rhs) noexcept;
std::ostream& operator<<(std::ostream& os, const {t.name}& obj);
std::istream& fromJson(std::istream& is, {t.name}& obj);
std::ostream& toJson(std::ostream& os, const {t.name}& obj);
'''
    )


def _gen_sequence_def_method_decl(bs, nl, stream, t):
    stream.write(
        f'''
//! {bs}class {t.name}{f'{f"{nl}//! {bs}brief {t.doc}" if t.doc else ""}'}
struct {t.name} {{
    {f";{nl}    ".join(_gen_field(m) for m in t.members)};
}};

// FREE OPERATORS
bool operator==(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator!=(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator<(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator>(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator<=(const {t.name}& lhs, const {t.name}& rhs) noexcept;
bool operator>=(const {t.name}& lhs, const {t.name}& rhs) noexcept;
std::ostream& operator<<(std::ostream& os, const {t.name}& obj);
std::istream& fromJson(std::istream& is, {t.name}& obj);
std::ostream& toJson(std::ostream& os, const {t.name}& obj);
'''
    )


def _gen_enum_def_method_decl(bs, nl, stream, t):
    stream.write(
        f'''
//! {bs}enum {t.name}{f'{f"{nl}//! {bs}brief {t.doc}" if t.doc else ""}'}
enum class {t.name} {{
    {f",{nl}    ".join(f"{m.name} = {m.value}" for m in t.members)}
}};

// FREE OPERATORS
std::ostream& operator<<(std::ostream& os, const {t.name}& obj);
std::istream& fromJson(std::istream& is, {t.name}& obj);
std::ostream& toJson(std::ostream& os, const {t.name}& obj);
'''
    )


def main(args: List[str]) -> None:
    parser = _opt_parser()
    opts = parser.parse_args(args)
    if opts.cmd == 'test':
        self_test()
        return
    elif opts.cmd == 'parse':
        print(_node_to_module(_parse_ast(opts.file.read())))
        return
    elif opts.cmd == 'gencpp':
        mod = _node_to_module(
            _parse_ast(opts.file.read(), opts.file.name),
            Path(opts.file.name).resolve().stem,
        )
        ns = opts.namespace or ''
        mod.validate()
        # print('Before topo sort:', mod.types)
        mod = Module(types=_topo_sort(mod.types), doc=mod.doc, name=mod.name)
        mod.validate()
        # print('After topo sort:', mod.types)
        _generate_hdr(mod, ns, opts.out_dir)
        return
    parser.print_help()
    raise SystemExit('Invalid usage')


## tests
def self_test():
    test = '''\
"""
Module doc.
"""

class Struct(Sequence):
    """
    Some 'Struct' documentation.
    """
    one: int
    two: float
    three: str
    four: bool
    four_and_half: TestEnum
    five: Optional[str] = None
    six: List['int'] = []
    seven: float = 3.14159


class TestEnum(Enum):
    """
    Some 'TestEnum' documentation.
    """
    ONE = 1
    TWO = 2


class Union(Choice):
    """
    Some 'Union' documentation.
    """
    one: int
    two: u32
    three: str
'''
    node = _parse_ast(test)
    mod = _node_to_module(node)
    assert mod == Module(
        types=[
            TypeDef(
                name='Struct',
                kind='sequence',
                members=[
                    Field(
                        name='one',
                        type_name='int',
                        is_optional=False,
                        is_list=False,
                        default_value=None,
                    ),
                    Field(
                        name='two',
                        type_name='float',
                        is_optional=False,
                        is_list=False,
                        default_value=None,
                    ),
                    Field(
                        name='three',
                        type_name='str',
                        is_optional=False,
                        is_list=False,
                        default_value=None,
                    ),
                    Field(
                        name='four',
                        type_name='bool',
                        is_optional=False,
                        is_list=False,
                        default_value=None,
                    ),
                    Field(
                        name='four_and_half',
                        type_name='TestEnum',
                        is_optional=False,
                        is_list=False,
                        default_value=None,
                    ),
                    Field(
                        name='five',
                        type_name='str',
                        is_optional=True,
                        is_list=False,
                        default_value=None,
                    ),
                    Field(
                        name='six',
                        type_name='int',
                        is_optional=False,
                        is_list=True,
                        default_value=None,
                    ),
                    Field(
                        name='seven',
                        type_name='float',
                        is_optional=False,
                        is_list=False,
                        default_value=3.14159,
                    ),
                ],
                doc="Some 'Struct' documentation.",
            ),
            TypeDef(
                name='TestEnum',
                kind='enum',
                members=[
                    Enumerator(name='ONE', value=1),
                    Enumerator(name='TWO', value=2),
                ],
                doc="Some 'TestEnum' documentation.",
            ),
            TypeDef(
                name='Union',
                kind='choice',
                members=[
                    Field(
                        name='one',
                        type_name='int',
                        is_optional=False,
                        is_list=False,
                        default_value=None,
                    ),
                    Field(
                        name='two',
                        type_name='u32',
                        is_optional=False,
                        is_list=False,
                        default_value=None,
                    ),
                    Field(
                        name='three',
                        type_name='str',
                        is_optional=False,
                        is_list=False,
                        default_value=None,
                    ),
                ],
                doc="Some 'Union' documentation.",
            ),
        ],
        doc='Module doc.',
        name='',
    )
    mod.validate()
    print('Test passed...')


## main

if __name__ == '__main__':
    import sys

    main(sys.argv[1:])
