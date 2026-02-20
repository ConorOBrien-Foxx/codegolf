start = Time.now

require 'cgi'
require 'digest'
require 'json'
require 'optparse'
require 'redcarpet'
require 'tzinfo'

CACHE_PATH = "./build/cache.json"
CHALLENGE_TEMPLATE = File.read "./build/challenge_template.html"
INDEX_TEMPLATE = File.read "./build/index_template.html"

class SmartQuoteRenderer < Redcarpet::Render::HTML
    def quote(q)
        "“#{q}”"
    end
end
MARKDOWN_RENDERER = SmartQuoteRenderer.new(render_options = {})
MARKDOWN = Redcarpet::Markdown.new(
    MARKDOWN_RENDERER,
    strikethrough: true,
    fenced_code_blocks: true,
    quote: true,
)

def digest(text)
    Digest::MD5.hexdigest text
end

module Tags
    NoInput = "no.i"
    StringInput = "string.i"
    StringOutput = "string.o"
    BooleanInput = "boolean.i"
    BooleanOutput = "string.o"
end

def format_test_cases(test_cases, tags)
    # TODO: saner
    # TODO: toggle between copy-pastable test cases
    alt = test_cases.map { |i, o| [i.chars, o] }
    t1 = test_cases.map { |i, o|
        "#{CGI::escapeHTML i.inspect} → #{CGI::escapeHTML o.inspect}"
    }.join "\n"
    t2 = alt.map { |i, o|
        "#{CGI::escapeHTML i.inspect} → #{CGI::escapeHTML o.inspect}"
    }.join "\n"
    return "<h2>Test Cases</h2>\n<pre><samp>#{t1}</samp></pre><h2>Test Cases (alternative)</h2>\n<pre><samp>#{t2}</samp></pre><p>(this will look better eventually, I promise)"
end

def now_in_my_home
    TZInfo::Timezone.get("America/New_York").strftime('%Y-%m-%d %H:%M:%S %z %Z')
end

def split_front_matter(md)
    lines = md.lines
    raise "expected front matter" unless lines[0].chomp == "---"
    next_front_delineator_idx = lines[1..-1].index { |line| line.chomp == "---" }
    if next_front_delineator_idx.nil?
        raise "unterminated front matter"
    end
    front_matter = JSON::parse lines[1..next_front_delineator_idx].join
    body = md.lines[next_front_delineator_idx + 2..-1].join
    [ front_matter, body ]
end

$force_rebuild = false
OptionParser.new { |opts|
    opts.banner = "Usage: build.rb [options]"
    opts.on("-h", "--help", "Prints this help") {
        puts opts
        exit
    }
    opts.on("-f", "--[no-]force", "Force rebuild all challenges (useful while developing build script)") { |v|
        $force_rebuild = v
    }
}.parse!

rows = []
cache = JSON::parse File.read CACHE_PATH

challenge_digest = digest CHALLENGE_TEMPLATE
index_digest = digest INDEX_TEMPLATE
unchanged_challenge_template = cache["_challenge"] == challenge_digest
unchanged_index_template = cache["_index"] == index_digest

cache_misses = 0
total = 0
Dir["build/*.md"].sort.each { |path|
    total += 1
    id = File.basename path, ".md"
    content = File.read path
    
    front_matter, body = split_front_matter content
    
    %w(name tags par).each { |prop|
        raise "Missing #{prop} in #{path}'s front matter" unless front_matter.has_key? prop
    }
    
    tags = front_matter["tags"].map { |tag| "<span class=\"category\">#{tag}</span>" }.join(" ")
    row = {
        id: id,
        name: front_matter["name"],
        tags: tags,
    }
    rows << row
    
    digest = digest content
    # only render HTML when necessary
    next if !$force_rebuild and unchanged_challenge_template and cache[id] and cache[id] == digest
    cache_misses += 1
    
    html_fragment = MARKDOWN.render body
    
    if front_matter["tags"].include? Tags::NoInput
        html_fragment += "<pre class=\"fixed-output\"><samp>#{CGI::escapeHTML front_matter["output"]}</pre></samp>"
    else
        html_fragment += format_test_cases front_matter["cases"], front_matter["tags"]
    end
    
    par = front_matter["par"].map { |lang, bytes| "#{lang}, #{bytes}b" }.join(" &bull; ")
    par = "<em>Nothing here, yet&hellip;</em>" if par.empty?
    
    page = CHALLENGE_TEMPLATE % {
        id: id,
        name: front_matter["name"],
        tags: tags,
        body: html_fragment,
        par: par,
        time: now_in_my_home,
    }
    
    File.write File.join("problems", "#{id}.html"), page
    
    cache[id] = digest
}

rows.map! { |row| <<EOT
        <tr>
            <td>#{row[:id]}</td>
            <td><a href="./problems/#{row[:id]}">#{row[:name]}</a></td>
            <td>#{row[:tags]}</td>
        </tr>
EOT
}

puts "Rebuilt #{cache_misses}/#{total} challenges"

unless cache_misses.zero? and unchanged_index_template and !$force_rebuild
    body = "
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Tags</th>
            </tr>
        </thead>
        <tbody>
    #{rows.join("\n")}
        </tbody>
    </table>
    ".gsub(/^/, "    ")

    File.write "index.html", INDEX_TEMPLATE % {
        listing: body,
        time: now_in_my_home
    }
end

cache["_index"] = index_digest
cache["_challenge"] = challenge_digest
File.write CACHE_PATH, cache.to_json

finish = Time.now
puts "Finished build in #{finish - start}s"