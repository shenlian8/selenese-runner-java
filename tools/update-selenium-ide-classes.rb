#!/usr/bin/ruby

require 'yaml'

main = File.expand_path("#{__dir__}/../src/main")
ARG_TYPES_JS = "#{main}/resources/selenium-ide/ArgTypes.js"
COMMANDS_JS = "#{main}/resources/selenium-ide/Commands.js"
ARG_TYPES = "#{main}/java/jp/vmi/selenium/runner/model/ArgTypes.java"

class Command

  attr_reader :arg_types, :commands

  class Lines

    def initialize(*args)
      @lines = args.dup
      @state = :js
    end

    def dq(s)
      s.gsub(/\"/, '\"')
    end

    def push(line)
      line.strip!
      case @state
      when :js
        line.gsub!(/\`(.*?)\`/) { '"' + dq($1) + '"' }
        if line.include?("`")
          line.sub!(/\`(.*)$/) { '"' + dq($1) }
          @state = :mlstr
        end
      when :mlstr
        if line.include?("`")
          line.sub!(/(.*?)\`/) { dq($1) + '"' }
          if line.include?("`")
            raise "Unsupported format."
          end
          @state = :js
        else
          line = dq(line)
        end
      end
      @lines.push(line)
    end

    def join
      @lines.join(' ')
    end

  end

  def start_reading(mstr)
    $stderr.puts("* Start reading #{mstr}")
  end

  def end_reading(mstr)
    $stderr.puts("* End reading #{mstr}")
  end

  def read_export(file, name)
    list = Lines.new
    state = :top_level
    File.foreach(file) do |line|
      case line
      when /^export\s+default\s*\{\s*$/
        start_reading(name)
        list.push('{')
        state = :export
      when /^\}\s*$/
        list.push('}')
        end_reading(name)
        state = :top_level
      else
        list.push(line) if state == :export
      end
    end
    list
  end

  def parse_list(list)
    parsed = YAML.load(list.join)
    map = {}
    parsed.each do |key, info|
      map[key] = info
    end
    map
  end

  def load
    arg_types_list = read_export(ARG_TYPES_JS, "ArgTypes")
    @arg_types = parse_list(arg_types_list)
    commands_list = read_export(COMMANDS_JS, "Commands")
    @commands = parse_list(commands_list)
  end
end

def to_const(s)
  s.gsub(/[A-Z]/, '_\&').upcase
end

def quote(s)
  s.gsub(/\\/, '\\\\').gsub(/"/, '\"')
end

def update_arg_types(cmd)
  $stderr.puts "* Update #{ARG_TYPES}"
  boa = "// BEGINNING OF ArgTypes"
  eoa = "// END OF ArgTypes"
  lines = {}
  mode = :prologue
  lines[mode] = []
  File.foreach(ARG_TYPES) do |line|
    case line
    when /#{boa}/
      lines[mode].push(line, '')
      mode = :items
      lines[mode] = []
    when /#{eoa}/
      mode = :epilogue
      lines[mode] = [line]
    else
      lines[mode].push(line)
    end
  end
  items = lines[:items] = []
  cmd.arg_types.each do |key, info|
    name = info["name"]
    desc = info["description"] || info["value"]
    items.push(<<-EOF)
    /** #{name} */
    #{to_const(key)}("#{quote(key)}", "#{quote(name)}",
        "#{quote(desc)}"),

    EOF
  end
  open(ARG_TYPES, 'wb') do |io|
    io.puts lines.values_at(:prologue, :items, :epilogue)
  end
end

cmd = Command.new
cmd.load
update_arg_types(cmd)
