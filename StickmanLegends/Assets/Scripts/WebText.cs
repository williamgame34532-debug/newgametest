using System.Text;
using System.Text.RegularExpressions;

namespace StickWars
{
    // Достаём читаемый текст персонажа со страницы: для вики (Fandom, Википедия) — через их API (чистый текст статьи
    // вместе с инфобоксом), для остальных сайтов — из HTML без скриптов и меню.
    public static class WebText
    {
        public const string UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 StickmanLegends/1.0";

        // https://xxx.fandom.com/ru/wiki/Имя  ->  https://xxx.fandom.com/ru/api.php?action=parse&page=Имя&prop=wikitext...
        // https://ru.wikipedia.org/wiki/Имя    ->  https://ru.wikipedia.org/w/api.php?...
        public static string WikiApiUrl(string url)
        {
            var m = Regex.Match(url, @"^(https?://[^/]+)(/[^?#]*?)?/wiki/([^?#]+)", RegexOptions.IgnoreCase);
            if (!m.Success) return null;
            string host = m.Groups[1].Value, prefix = m.Groups[2].Value, title = m.Groups[3].Value;
            string api = host.Contains("wikipedia.org") || host.Contains("wikimedia.org") ? host + "/w/api.php" : host + prefix + "/api.php";
            return api + "?action=parse&prop=wikitext&format=json&formatversion=2&redirects=1&page=" + title;
        }

        // ответ API -> текст
        public static string FromWikiJson(string json, out string title)
        {
            title = JsonString(json, "title");
            string wt = JsonString(json, "wikitext");
            if (string.IsNullOrEmpty(wt)) return "";
            return FromWikitext(wt);
        }

        // разметка вики -> обычный текст; поля инфобокса превращаются в предложения «Способности: ...»
        public static string FromWikitext(string s)
        {
            s = Regex.Replace(s, @"<ref[^>]*/>", " ", RegexOptions.IgnoreCase);
            s = Regex.Replace(s, @"<ref[^>]*>.*?</ref>", " ", RegexOptions.IgnoreCase | RegexOptions.Singleline);
            s = Regex.Replace(s, @"<!--.*?-->", " ", RegexOptions.Singleline);
            s = Regex.Replace(s, @"\[\[(?:Файл|File|Изображение|Image|Категория|Category):[^\]]*(\[\[[^\]]*\]\][^\]]*)*\]\]", " ", RegexOptions.IgnoreCase);
            s = Regex.Replace(s, @"\[\[(?:[^|\]]*\|)?([^\]]*)\]\]", "$1");
            s = Regex.Replace(s, @"\[https?://[^\s\]]+\s?([^\]]*)\]", "$1");
            // поля шаблонов: «| способности = ...» -> «способности: ...»
            s = Regex.Replace(s, @"^[ \t]*\|[ \t]*([^=\n|]{2,40}?)[ \t]*=[ \t]*(.*)$", m => m.Groups[2].Value.Trim().Length > 0 ? m.Groups[1].Value.Trim() + ": " + m.Groups[2].Value.Trim() + "." : "", RegexOptions.Multiline);
            // многострочные шаблоны-инфобоксы: снимаем «обёртку», поля уже стали предложениями
            s = Regex.Replace(s, @"\{\{[^{}\n|]*\n", "\n");
            s = Regex.Replace(s, @"^[ \t]*\}\}[ \t]*$", "", RegexOptions.Multiline);
            s = Regex.Replace(s, @"\{\{[^{}|]*\|([^{}]*)\}\}", "$1");
            s = Regex.Replace(s, @"\{\{[^{}]*\}\}", " ");
            s = s.Replace("{{", " ").Replace("}}", " ");
            s = Regex.Replace(s, @"'{2,}", "");
            s = Regex.Replace(s, @"^=+\s*(.*?)\s*=+\s*$", "$1.", RegexOptions.Multiline);
            s = Regex.Replace(s, @"^[\*#:;]+\s*", "", RegexOptions.Multiline);
            s = Regex.Replace(s, @"<br\s*/?>", ". ", RegexOptions.IgnoreCase);
            s = Regex.Replace(s, @"<[^>]+>", " ");
            s = Regex.Replace(s, @"\{\|.*?\|\}", " ", RegexOptions.Singleline); // таблицы
            s = Decode(s);
            var sb = new StringBuilder();
            foreach (var line in s.Split('\n'))
            {
                string l = Regex.Replace(line, @"\s+", " ").Trim();
                if (l.Length < 3) continue;
                sb.Append(l);
                if (!l.EndsWith(".") && !l.EndsWith("!") && !l.EndsWith("?") && !l.EndsWith(":")) sb.Append('.');
                sb.Append(' ');
            }
            return sb.ToString().Trim();
        }

        public static string Extract(string html, out string title)
        {
            title = null;
            if (string.IsNullOrEmpty(html)) return "";
            var tm = Regex.Match(html, @"<title[^>]*>(.*?)</title>", RegexOptions.IgnoreCase | RegexOptions.Singleline);
            if (tm.Success)
            {
                title = Decode(tm.Groups[1].Value).Trim();
                int cut = title.IndexOfAny(new[] { '|', '—', '–' });
                if (cut > 2) title = title.Substring(0, cut).Trim();
            }
            string s = html;
            // если есть тело статьи вики — берём только его
            int art = s.IndexOf("mw-parser-output", System.StringComparison.Ordinal);
            if (art < 0) art = s.IndexOf("<article", System.StringComparison.OrdinalIgnoreCase);
            if (art < 0) art = s.IndexOf("<main", System.StringComparison.OrdinalIgnoreCase);
            if (art > 0) s = s.Substring(art);
            s = Regex.Replace(s, @"<(script|style|noscript|svg|nav|footer|form|button|select|template)\b[^>]*>.*?</\1\s*>", " ", RegexOptions.IgnoreCase | RegexOptions.Singleline);
            s = Regex.Replace(s, @"<!--.*?-->", " ", RegexOptions.Singleline);
            // абзацы, строки инфобокса и переносы — в точки, чтобы парсер видел границы предложений
            s = Regex.Replace(s, @"</?(br|p|li|h[1-6]|div|tr|dd|dt|section|aside|figure)\b[^>]*>", ".\n", RegexOptions.IgnoreCase);
            s = Regex.Replace(s, @"</(td|th|h3)>", ": ", RegexOptions.IgnoreCase);
            s = Regex.Replace(s, @"<[^>]+>", " ");
            s = Decode(s);
            s = Regex.Replace(s, @"\[\d+\]", " ");              // сноски вики
            s = Regex.Replace(s, @"[ \t\r\f\v]+", " ");
            s = Regex.Replace(s, @"(\s*\.\s*\n\s*)+", ".\n");
            var sb = new StringBuilder();
            foreach (var line in s.Split('\n'))
            {
                string l = line.Trim().Trim('.').Trim();
                if (l.Length < 4) continue;
                if (l.Length < 25 && !Regex.IsMatch(l, @"(слаб|уязв|способн|сил|оруж|здоров|цвет|рост|вид|weak|abilit|power|weapon)", RegexOptions.IgnoreCase) && !l.Contains(":")) continue;
                sb.Append(l).Append(". ");
            }
            return sb.ToString().Trim();
        }

        // значение строкового поля JSON без сторонних библиотек
        static string JsonString(string json, string key)
        {
            var m = Regex.Match(json, "\"" + key + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"", RegexOptions.Singleline);
            if (!m.Success) return null;
            string v = m.Groups[1].Value;
            var sb = new StringBuilder(v.Length);
            for (int i = 0; i < v.Length; i++)
            {
                char c = v[i];
                if (c != '\\' || i + 1 >= v.Length) { sb.Append(c); continue; }
                char n = v[++i];
                switch (n)
                {
                    case 'n': sb.Append('\n'); break;
                    case 't': sb.Append(' '); break;
                    case 'r': break;
                    case 'u':
                        if (i + 4 < v.Length) { sb.Append((char)System.Convert.ToInt32(v.Substring(i + 1, 4), 16)); i += 4; }
                        break;
                    default: sb.Append(n); break;
                }
            }
            return sb.ToString();
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
