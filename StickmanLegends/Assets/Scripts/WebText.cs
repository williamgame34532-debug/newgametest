using System.Text;
using System.Text.RegularExpressions;

namespace StickWars
{
    // Достаём читаемый текст из HTML-страницы (вики, фэндом, блог): без скриптов, меню и тегов
    public static class WebText
    {
        public static string Extract(string html, out string title)
        {
            title = null;
            if (string.IsNullOrEmpty(html)) return "";
            var tm = Regex.Match(html, @"<title[^>]*>(.*?)</title>", RegexOptions.IgnoreCase | RegexOptions.Singleline);
            if (tm.Success)
            {
                title = Decode(tm.Groups[1].Value).Trim();
                int cut = title.IndexOfAny(new[] { '|', '—', '–', '-' });
                if (cut > 2) title = title.Substring(0, cut).Trim();
            }
            string s = html;
            s = Regex.Replace(s, @"<(script|style|noscript|svg|nav|footer|header|aside|form|button|select|template)[^>]*>.*?</\1>", " ", RegexOptions.IgnoreCase | RegexOptions.Singleline);
            s = Regex.Replace(s, @"<!--.*?-->", " ", RegexOptions.Singleline);
            // абзацы и переносы — в точки, чтобы парсер видел границы предложений
            s = Regex.Replace(s, @"<(br|/p|/li|/h[1-6]|/div|/tr|/td|/dd|/dt)[^>]*>", ".\n", RegexOptions.IgnoreCase);
            s = Regex.Replace(s, @"<[^>]+>", " ");
            s = Decode(s);
            s = Regex.Replace(s, @"\[\d+\]", " ");              // сноски вики
            s = Regex.Replace(s, @"[ \t\r\f\v]+", " ");
            s = Regex.Replace(s, @"(\s*\.\s*\n\s*)+", ".\n");
            // выкидываем короткие обрывки меню, оставляем строки с текстом
            var sb = new StringBuilder();
            foreach (var line in s.Split('\n'))
            {
                string l = line.Trim().Trim('.').Trim();
                if (l.Length < 25 && !Regex.IsMatch(l, @"(слаб|уязв|способн|сил|оруж|здоров|weak|abilit|power|weapon)", RegexOptions.IgnoreCase)) continue;
                sb.Append(l).Append(". ");
            }
            return sb.ToString().Trim();
        }

        static string Decode(string s)
        {
            s = s.Replace("&nbsp;", " ").Replace("&amp;", "&").Replace("&quot;", "\"").Replace("&#39;", "'").Replace("&lt;", "<").Replace("&gt;", ">").Replace("&laquo;", "«").Replace("&raquo;", "»").Replace("&mdash;", "—").Replace("&ndash;", "–");
            s = Regex.Replace(s, @"&#(\d+);", m => { int c; return int.TryParse(m.Groups[1].Value, out c) && c < 0x10FFFF ? char.ConvertFromUtf32(c) : " "; });
            s = Regex.Replace(s, @"&#x([0-9a-fA-F]+);", m => { try { return char.ConvertFromUtf32(System.Convert.ToInt32(m.Groups[1].Value, 16)); } catch { return " "; } });
            return s;
        }
    }
}
