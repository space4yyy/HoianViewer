using System;
using System.Text;
using System.Text.RegularExpressions;

namespace BfresEditor
{
    public partial class TegraShaderDecoder
    {
        //Raiders' model light tables are read-only uint arrays. Uniform buffers
        //provide the same raw words on OpenGL 4.1 without requiring an SSBO API.
        static string MacReadonlyStorageSource(string source)
        {
            var instances = new System.Collections.Generic.List<string>();
            source = Regex.Replace(source,
                @"layout\s*\([^)]*std430[^)]*\)\s*(?:readonly\s+)?buffer\s+_([vf]p_s\d+)\s*\{\s*uint\s+data\s*\[\s*\]\s*;\s*\}\s*\1\s*;",
                match =>
                {
                    string name = match.Groups[1].Value;
                    instances.Add(name);
                    return $"layout (std140) uniform _{name} {{ uvec4 words[4096]; }} {name};\n"
                        + $"uint pv_read_{name}(int index) {{ return {name}.words[index >> 2][index & 3]; }}";
                });
            foreach (string instance in instances)
            {
                string token = instance + ".data[";
                var writeAccess = new Regex(@"\G\s*(?:=(?!=)|[+\-*/&|^%]=|\+\+|--)");
                var converted = new StringBuilder(source.Length);
                int start = 0;
                while (true)
                {
                    int access = source.IndexOf(token, start, StringComparison.Ordinal);
                    if (access < 0)
                        break;
                    int expression = access + token.Length, depth = 1, end = expression;
                    for (; end < source.Length && depth != 0; end++)
                    {
                        if (source[end] == '[') depth++;
                        if (source[end] == ']') depth--;
                    }
                    if (depth != 0)
                        throw new InvalidOperationException("Unterminated translated storage buffer access.");
                    if (writeAccess.IsMatch(source, end))
                        throw new NotSupportedException("macOS cannot emulate writes to a shader storage buffer.");
                    converted.Append(source, start, access - start);
                    converted.Append("pv_read_").Append(instance).Append("(int(");
                    converted.Append(source, expression, end - expression - 1).Append("))");
                    start = end;
                }
                converted.Append(source, start, source.Length - start);
                source = converted.ToString();
            }
            return source;
        }
    }
}
