require 'rexml/document'

# A class used for the list only
class SvnListEntry
  attr_accessor :name, :kind, :revision, :author, :date  
end

# A class that handles subversion interaction for this system
# it uses an external 'svn' command
class SubversionManager
  
  attr_reader :subversion_command
  
  def initialize( svn_command = 'svn' )
    @subversion_command = svn_command
  end
  
  def create_directory( username, password, server, path )
    begin
      rtn = ''
      
      slash = (server[-1..-1].to_s.eql?('/')) ? '' : '/' 
      command_front = "#{@subversion_command} info --username #{username} --password #{password} --non-interactive --xml  #{server}#{slash}"
      
      paths = Array.new 
      paths.push( path )
      tmp_path = String.new( path )
      while( ! tmp_path.index('/').nil? )
        tmp_path = tmp_path[0..tmp_path.rindex('/')-1]
#puts "#{tmp_path}"
        paths << tmp_path 
      end
    
      # find the directory that doesn't exist
      index = 0
      good = false
      while !good
        command = "#{command_front}#{paths[index]} 2>&1"
#puts "I: #{index} - #{paths[index]}"
#puts "C: #{command}"
        result = `#{command}`
#puts "R: #{result}"
        unless result.index('Not a valid URL').nil?
          rnt = "#{rtn} \n Missing Directory: #{paths[index]}."
          index = index + 1
          if ( index >= paths.size ) 
            raise "Subversion root does not seem to exists"
          end
        else
          good = true
          index = index - 1
        end
      end
      
      while index >= 0
        command = "#{@subversion_command} mkdir --username #{username} --password #{password} --non-interactive -m \"AUTOMATIC DIRECTORY CREATION OF '#{paths[index]}'\" #{server}#{slash}#{paths[index]}"
#puts "C: #{command}"
        result = `#{command} 2>&1`
#puts "R: #{result}"
        if result.index('Committed revision').nil?
          raise "Failed to create directory #{paths[index]}"
        end
        rtn = "#{rtn} \n Created Directory: #{paths[index]}"
        index = index - 1
      end
    
      return rtn
    rescue  Exception => ex
      #puts ex.message
      if result.class.to_s.eql?('String') && !result.index('authorization failed').nil?
        raise "Authorization failed for user #{username} using the supplied password."
      else
        raise "Subversion Error."
      end
    end 
  end
  
  def list( username, password, server, path )
    begin
      slash = (server[-1..-1].to_s.eql?('/')) ? '' : '/' 
      command = "#{@subversion_command} list --username #{username} --password #{password} --non-interactive --xml -R #{server}#{slash}#{path}  2>&1"
      result = `#{command}`

      xml = REXML::Document.new( result )
  
      @entry_arr = nil
      xml.root.each_element("list") do |list|
        @entry_arr = list.elements
      end
    
      entries = Array.new
      1.upto( @entry_arr.size ) do |i|
        entry = SvnListEntry.new
        entry.name = xml_get_name( @entry_arr[i] )
        entry.kind = xml_get_kind( @entry_arr[i] )
        entry.revision = xml_get_revision( @entry_arr[i] )
        entry.author = xml_get_author( @entry_arr[i] )
        entry.date = xml_get_date( @entry_arr[i] )
        #puts "#{entry.inspect}"
        entries << entry
      end
    
      return entries
    rescue Exception => ex
      #puts ex.message
      if !result.index('non-existent').nil?
        raise "#{path} non-existent in the current revision."
      elsif !result.index('authorization failed').nil?
        raise "Authorization failed for user #{username} using the supplied password."
      else
        raise "Subversion Error."
      end
    end
  end
  
  
  private
  def xml_get_author( element )
    element.each_element("//author") { |e| return e.get_text }
  end
  
  def xml_get_date( element )
    element.each_element("//date") { |e| return e.get_text }
  end

  def xml_get_name( element )
    element.each_element("name") { |e| return e.get_text }
  end

  def xml_get_revision( element )
    element.each_element("commit") { |e| return e.attributes['revision'] }
  end
  
  def xml_get_kind( element )
    element.attributes['kind']
  end
  
  
  
end