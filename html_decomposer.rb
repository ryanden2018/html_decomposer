#!/usr/bin/env ruby


def find_closing_tags(tokens)
  tokens.select do |token|
    !!token.match(/\A<\s*\/[^<>]*>\z/)
  end.map do |token|
    token.gsub(/[^A-Za-z0-9]/," ").strip.split(" ")[0]&.downcase
  end
end

def escape(str)
  str.gsub("<","&lt;").gsub(">","&gt;")
end

def is_opening_tag(str)
  !!str.match(/\A<\s*[^\/<>][^<>]*>\z/)
end

def is_closing_tag(str)
  !!str.match(/\A<\s*\/[^<>]*>\z/)
end

def is_tag(str)
  !!str.match(/\A<[^<>]*>\z/)
end

def tags_match(opening,closing)
  opening_name = opening.gsub(/[^A-Za-z0-9]/," ").strip.split(" ")[0]&.downcase
  closing_name = closing.gsub(/[^A-Za-z0-9]/," ").strip.split(" ")[0]&.downcase
  opening_name == closing_name
end


def has_closing_tag(token,closing_tags)
  tag_name = token.gsub(/[^A-Za-z0-9]/," ").strip.split(" ")[0]&.downcase
  closing_tags.include?(tag_name)
end

def generate_closing_tag(token)
  tag_name = token.gsub(/[^A-Za-z0-9]/," ").strip.split(" ")[0]&.downcase
  "</#{tag_name}>"
end


def decompose_html_helper(tokens_with_depth,closing_tags,depth=0)
  if tokens_with_depth.length == 0
    return []
  end

  results = []
  segment = []
  tag = ""

  i = 0
  while i < tokens_with_depth.length
    token = tokens_with_depth[i][0]
    token_depth = tokens_with_depth[i][1]

    if is_opening_tag(token) && has_closing_tag(token,closing_tags) && (token_depth == depth)
      tag = token
      segment = []
    elsif token_depth > depth
      segment << [token,token_depth]
    elsif is_closing_tag(token) && (token_depth == depth) && tags_match(tag,token)
      results << {tag: tag, contents: decompose_html_helper(segment,closing_tags,depth+1)}
    else 
      results << token
    end
    i += 1
  end

  results
end


def decompose_html(tokens)
  closing_tags = find_closing_tags(tokens)
  
  tokens_with_depth = []

  depth = 0

  i = 0
  while i < tokens.length
    token = tokens[i]
    if is_tag(token)
      if is_opening_tag(token) && has_closing_tag(token,closing_tags)
        tokens_with_depth << [token,depth]
        depth += 1
      elsif is_closing_tag(token)
        if depth > 0
          depth -= 1
        end
        tokens_with_depth << [token,depth]
      else
        tokens_with_depth << [token,depth]
      end
    else
      tokens_with_depth << [token,depth]
    end

    i += 1
  end
  
  decompose_html_helper(tokens_with_depth,closing_tags)
end


def output_html(html_hashed,fout,depth=0)
  tab = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"

  i = 0
  while i < html_hashed.length
    elem = html_hashed[i]

    if elem.class == Hash
      fout.write(tab*depth + escape(elem[:tag]) + "<br>\n")
      output_html(elem[:contents],fout,depth+1)
      fout.write(tab*depth + escape(generate_closing_tag(elem[:tag])) + "<br>\n")
    elsif elem.class == String
      fout.write(tab*depth + escape(elem) + "<br>\n")
    end

    i += 1
  end
end


if !ARGV[0] || !ARGV[1]
  puts "Usage: ruby html_decomposer.rb infile outfile"
  exit
end

# read input file from arglist
fin = nil
begin
  fin = File.new(ARGV[0],"r")
rescue
  puts "I/O error: file #{ARGV[0]} could not be read"
  exit
end

contents = nil
if fin
  contents = fin.read
  fin.close
else
  puts "I/O error: file #{ARGV[0]} could not be read"
  exit
end


# split file into tokens ("<html>", "<head>", textual blocks, ...)
tokens = contents.scan(/<[^>]*>|[^<>]+/).map { |token| token.strip }


# open output file for writing
fout = File.new(ARGV[1],"w")

if fout
  fout.write("<!DOCTYPE html>\n")
  fout.write("<html>\n")
  fout.write("<head>\n")
  fout.write("<title>HTML Output</title>\n")
  fout.write("<style type='text/css'>\nbody {font-family:courier,courier new,serif;}</style>")
  fout.write("</head>\n")
  fout.write("<body>\n")

  html_hashed = decompose_html(tokens)

  output_html(html_hashed,fout)

  fout.write("</tt>\n")
  fout.write("</body>\n")
  fout.write("</html>\n")

  fout.close
else
  puts "I/O error: file #{ARGV[1]} could not be opened for writing"
  exit
end