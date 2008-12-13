#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008 OpsCode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'rubygems'
require 'extlib'
require 'ohai/log'
require 'ohai/mixin/from_file'
require 'ohai/mixin/command'
require 'json'

module Ohai
  class System
    attr_accessor :data, :seen_plugins
    
    include Ohai::Mixin::FromFile
    include Ohai::Mixin::Command
    
    def initialize
      @data = Mash.new
      @seen_plugins = Hash.new
    end
    
    def [](key)
      @data[key]
    end
    
    def []=(key, value)
      @data[key] = value
    end
    
    def attribute?(name)
      Ohai::Log.debug("Attribute #{name} is #{@data.has_key?(name)}")
      @data.has_key?(name) 
    end
    
    def set(name, *value)
      set_attribute(name, *value)
    end
    
    def from(cmd)
      status, stdout, stderr = run_command(:command => cmd)
      stdout.chomp!
    end
    
    # Set the value equal to the stdout of the command, plus run through a regex - the first piece of match data is the value.
    def from_with_regex(cmd, *regex_list)
      regex_list.flatten.each do |regex|
        status, stdout, stderr = run_command(:command => cmd)
        stdout.chomp!
        md = stdout.match(regex)
        return md[1]
      end
    end
    
    def set_attribute(name, *value)
      Ohai::Log.debug("Setting attribute #{name} to #{value.inspect}")
      @data[name] = *value
      @data[name]
    end
    
    def get_attribute(name)
      Ohai::Log.debug("Getting attribute #{name}, value #{@data[name].inspect}")
      @data[name]
    end
    
    def all_plugins
      require_plugin('os')
      
      Ohai::Config[:plugin_path].each do |path|
        [ 
          Dir[File.join(path, '*')], 
          Dir[File.join(path, @data[:os], '**', '*')] 
        ].flatten.each do |file|
          file_regex = Regexp.new("#{path}#{File::SEPARATOR}(.+).rb$")
          md = file_regex.match(file)
          if md
            plugin_name = md[1].gsub(File::SEPARATOR, "::") 
            require_plugin(plugin_name) unless @seen_plugins.has_key?(plugin_name)
          end
        end
      end
    end
    
    def require_plugin(plugin_name, force=false)
      unless force
        return true if @seen_plugins[plugin_name]
      end
      
      filename = "#{plugin_name.gsub("::", File::SEPARATOR)}.rb"
            
      Ohai::Config[:plugin_path].each do |path|
        check_path = File.expand_path(File.join(path, filename))
        begin
          @seen_plugins[plugin_name] = true
          Ohai::Log.info("Loading plugin #{plugin_name}")
          from_file(check_path)
          return true
        rescue IOError => e
          Ohai::Log.debug("No #{plugin_name} at #{check_path}")
        rescue Exception => e
          Ohai::Log.debug("Plugin #{plugin_name} threw exception #{e.inspect}")
        end
      end
    end
    
    # Sneaky!  Lets us stub out require_plugin when testing plugins, but still
    # call the real require_plugin to kick the whole thing off.
    alias :_require_plugin :require_plugin
    
    # Serialize this object as a hash 
    def to_json(*a)
      output = @data.clone
      output["json_class"] = self.class.name
      output.to_json(*a)
    end
    
    # Pretty Print this object as JSON 
     def json_pretty_print
       JSON.pretty_generate(@data)
     end
    
    # Create an Ohai::System from JSON
    def self.json_create(o)
      ohai = new
      o.each do |key, value|
        ohai.data[key] = value unless key == "json_class"
      end
      ohai
    end
    
    def method_missing(name, *args)
      return get_attribute(name) if args.length == 0 
      
      set_attribute(name, *args)
    end
    
    private
      def load_plugin_file
        
      end
  end
end
