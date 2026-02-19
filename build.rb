start = Time.now

require 'cgi'
require 'json'
require 'redcarpet'
require 'tzinfo'

CHALLENGE_TEMPLATE = File.read "./build/challenge_template.html"
INDEX_TEMPLATE = File.read "./build/index_template.html"
MARKDOWN_RENDERER = Redcarpet::Render::HTML.new(render_options = {})
MARKDOWN = Redcarpet::Markdown.new(
    MARKDOWN_RENDERER,
    strikethrough: true,
    fenced_code_blocks: true,
)

module Tags
    NoInput = "no.i"
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

rows = []

Dir["build/*.md"].sort.each { |path|
    id = File.basename path, ".md"
    content = File.read path
    front_matter, body = split_front_matter content
    html_fragment = MARKDOWN.render body
    
    if front_matter["tags"].include? Tags::NoInput
        html_fragment += "<pre class=\"fixed-output\"><samp>#{CGI::escapeHTML front_matter["output"]}</pre></samp>"
    else
        html_fragment += "TODO: "
        html_fragment += front_matter["cases"].to_json
    end
    
    tags = front_matter["tags"].map { |tag| "<span class=\"category\">#{tag}</span>" }.join(" ")
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
    
    row = {
        id: id,
        name: front_matter["name"],
        tags: tags,
    }
    rows << row
}

rows.map! { |row| <<EOT
        <tr>
            <td>#{row[:id]}</td>
            <td><a href="./problems/#{row[:id]}">#{row[:name]}</a></td>
            <td>#{row[:tags]}</td>
        </tr>
EOT
}

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

finish = Time.now
puts "Finished build in #{finish - start}s"