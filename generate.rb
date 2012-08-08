require 'field'
require 'textbox'

class Generate
  def initialize()
    @protocol_name = ''
    @protocol_abbrev = ''
    @port = ''
    @path = '/usr/src/wireshark'
  end

  def go(incoming, outgoing)
    @protocol_name   = Textbox.new(@protocol_name).prompt("Protocol name: ")
    @protocol_abbrev = Textbox.new(@protocol_abbrev).prompt("Protocol abbreviation (lowercase): ")
    @port            = Textbox.new(@port).prompt("Port: ")
    @path            = Textbox.new(@path).prompt("Path to Wireshark source: ")


    str = <<EOF
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <string.h>
#include <glib.h>

#include <epan/packet.h>
#include <epan/emem.h>
#include "packet-dns.h"
#include "packet-netbios.h"
#include "packet-tcp.h"
#include "packet-frame.h"
#include <epan/prefs.h>
#include <epan/strutil.h>

static int proto_#{@protocol_abbrev} = -1;
static gint ett_#{@protocol_abbrev} = -1;
((VARIABLES))

/* This is a temporary hack till I find a better way to fix the warning. */
#define TVB_WARNING_HACK tvb_get_guint8(tvb, 0); 

/* -- begin auto-generated prototypes -- */
((PROTOTYPES))
/* -- end auto-generated prototypes -- */

/* -- begin auto-generated functions -- */
((FUNCTIONS))
/* -- end auto-generated functions -- */

static void dissect_#{@protocol_abbrev}(tvbuff_t *tvb, packet_info *pinfo, proto_tree *tree)
{
  int            position = 0;
  guint16        id;

  /* This sets the string in the "Protocol" column. */
  col_set_str(pinfo->cinfo, COL_PROTOCOL, "#{@protocol_abbrev}");

  /* Check if we should display the 'description' column, and set it if we do. */
  col_clear(pinfo->cinfo, COL_INFO);
  if(check_col(pinfo->cinfo, COL_INFO))
  {
    /* This is the column 'description' that's printed. */
    col_add_fstr(pinfo->cinfo, COL_INFO, "#{@protocol_name}");
  }


  /* Only build the tree if we were passed one. */
  if (tree)
  {
    proto_item *ti                       = proto_tree_add_item(tree, proto_#{@protocol_abbrev}, tvb, position, -1, FALSE);
    proto_tree *#{@protocol_abbrev}_tree = proto_item_add_subtree(ti, ett_#{@protocol_abbrev});

    /* This is the value that will be displayed. */
    id = tvb_get_ntohs(tvb, 0);

    /* buffer, where to highlight, how long to highlight, which value to show. */
    if(pinfo->destport == #{@port})
    {
      ((ADD_OUTGOING_FIELDS))
    }
    else
    {
      ((ADD_INCOMING_FIELDS))
    }
  }
}

void proto_register_#{@protocol_abbrev}(void)
{
  static hf_register_info hf_#{@protocol_abbrev}[] = {
((REGISTER_FIELDS))
  };

  static gint *ett[] = {
    &ett_#{@protocol_abbrev},
  };

  proto_#{@protocol_abbrev} = proto_register_protocol("#{@protocol_name}", "#{@protocol_abbrev}", "#{@protocol_abbrev}"); /* Name, shortname, abbrev. */
  proto_register_field_array(proto_#{@protocol_abbrev}, hf_#{@protocol_abbrev}, array_length(hf_#{@protocol_abbrev}));

  proto_register_subtree_array(ett, array_length(ett));
}

void proto_reg_handoff_#{@protocol_abbrev}(void)
{
  dissector_handle_t #{@protocol_abbrev}_handle;

  #{@protocol_abbrev}_handle = create_dissector_handle(dissect_#{@protocol_abbrev}, proto_#{@protocol_abbrev});
  dissector_add_uint("udp.port", #{@port}, #{@protocol_abbrev}_handle);
}

EOF

    register_fields = []
    get_length_functions  = []
    functions  = []
    functions   = []
    add_outgoing_fields = []
    add_incoming_fields = []
    i = 0
    variables = []

    outgoing.each_field do |name, field|
      type = Field::TYPES[field.type]
      # This gets the 'registration' line, which tells Wireshark that the field exists
      register_fields << get_register_field(name, 'outgoing', field)

      # This gets the 'add' line, which actively adds the value to the protocol tree
      # (this also looks after 'optional' values)
      add_outgoing_fields << get_add_field(name, 'outgoing', field, type)

      # Get the variable declaration for the header field
      variables << get_variable_declaration(name, 'outgoing', field)

      # Get the auto-generated functions
      functions << get_length_function(name, 'outgoing', field, type)
      functions << get_position_function(name, 'outgoing', field, type, outgoing)
      functions << get_value_function(name, 'outgoing', field, type)
    end

    incoming.each_field do |name, field|
      type = Field::TYPES[field.type]
      # This gets the 'registration' line, which tells Wireshark that the field exists
      register_fields << get_register_field(name, 'incoming', field)

      # This gets the 'add' line, which actively adds the value to the protocol tree
      # (this also looks after 'optional' values)
      add_incoming_fields << get_add_field(name, 'incoming', field, type)

      # Get the variable declaration for the header field
      variables << get_variable_declaration(name, 'incoming', field)

      # Get the auto-generated functions
      functions << get_length_function(name, 'incoming', field, type)
      functions << get_position_function(name, 'incoming', field, type, incoming)
      functions << get_value_function(name, 'incoming', field, type)
    end

    # Auto-generate prototypes
    prototypes = []
    functions.each do |function|
      prototypes << function.split("\n")[0].gsub(" {", "").strip + ';'
    end

    str.gsub!('((REGISTER_FIELDS))',     register_fields.join("\n"))
    str.gsub!('((ADD_OUTGOING_FIELDS))', add_outgoing_fields.join("\n"))
    str.gsub!('((ADD_INCOMING_FIELDS))', add_incoming_fields.join("\n"))
    str.gsub!('((VARIABLES))',           variables.join("\n"))
    str.gsub!('((PROTOTYPES))',          prototypes.join("\n"))
    str.gsub!('((FUNCTIONS))',           functions.join("\n"))

    dissector_path = "#{@path}/epan/dissectors"
    dissector_filename = "packet-#{@protocol_abbrev}.c"
    File.open("#{dissector_path}/#{dissector_filename}", 'w') do |f|
      f.puts(str)
    end

    lines = []
    File.open(@path + '/epan/dissectors/Makefile.common', 'r') do |f|
      # Loop until we find the DISSECTOR_SRC block
      loop do
        line = f.gets
        if(line.nil?)
          MessageBox.new("Error: couldn't find DISSECTOR_SRC in %s" % (@path + '/epan/dissectors/Makefile.common')).go
          exit
        end
        line.chomp!
        lines << line

        if(line =~ /^DISSECTOR_SRC/)
          break
        end
      end

      # Insert our filename at the right location
      i = 0
      found = false
      spaces = "\t"
      loop do
        line = f.gets
        if(line.nil?)
          break
        end
        line.chomp!

        spaces, filename = line.scan(/^(\s*)([^\s]+)/).pop
        #puts("'%s' -> '%s' '%s'\n" % [line, spaces, filename])
        if(filename == dissector_filename)
          found = true
          lines << line
          break
        end

        if(filename > dissector_filename)
          found = true
          lines << "#{spaces}#{dissector_filename} #{' '*(23 - dissector_filename.length)}\\"
          lines << line
          break
        end
        lines << line

        if(!line.match(/\\\s*(#.*|)$/))
          break
        end
      end 
      if(!found)
        line = lines.pop
        line = line + " #{' '*(23 - dissector_filename.length)}\\"
        lines << line
        lines << "#{spaces}#{dissector_filename}"
      end

      loop do
        line = f.gets
        if(line.nil?)
          break
        end
        line.chomp!
        lines << line
      end
    end # open file

    # Write back to Makefile.common
    File.open(@path + '/epan/dissectors/Makefile.common', 'w') do |f|
      f.write(lines.join("\n"))
      f.write("\n")
    end


#    File.open(@path + '/epan/CMakeLists.txt', 'r') do |f|
#      puts(f.gets())
#    end
    lines = []
    File.open(@path + '/epan/CMakeLists.txt', 'r') do |f|
      # Loop until we find the DISSECTOR_SRC block
      loop do
        line = f.gets
        if(line.nil?)
          MessageBox.new("Error: couldn't find DISSECTOR_SRC in %s" % (@path + '/epan/dissectors/Makefile.common')).go
          Ncurses.endwin
          exit
        end
        line.chomp!
        lines << line

        if(line =~ /^set\(DISSECTOR_SRC/)
          break
        end
      end

      # Insert our filename at the right location
      i = 0
      found = false
      path = "\tdissectors/"
      loop do
        line = f.gets
        if(line.nil?)
          break
        end
        line.chomp!
        if(line.match(/\s*\)\s*(#.*|)/))
          lines << line
          break
        end

        path, filename = line.scan(/^(\s*.*\/)([^\s]+)/).pop
        if(filename.nil?)
          lines << line
        else
          if(filename == dissector_filename)
            found = true
            lines << line
            break
          end
  
          if(filename > dissector_filename)
            found = true
            lines << "#{path}#{dissector_filename}"
            lines << line
            break
          end
          lines << line
 
        end 
      end
      if(!found)
        line = lines.pop
        lines << "#{path}#{dissector_filename}"
        lines << line
      end

      loop do
        line = f.gets
        if(line.nil?)
          break
        end
        line.chomp!
        lines << line
      end
    end # open file
    File.open(@path + '/epan/CMakeLists.txt', 'w') do |f|
      f.write(lines.join("\n"))
      f.write("\n")
    end

    MessageBox.new("Files successfully updated! Compile Wireshark as usual, now.").go
  end

  def get_register_field(name, direction, field)
      return "    { &hf_#{name}_#{direction},  { \"#{name}\", \"#{@protocol_abbrev}.#{name}\", #{Field::TYPES_FT[field.type]}, #{Field::TYPES_BASE[field.type]}, NULL, 0x0, \"#{name}\", HFILL }},"
  end

  def get_add_field(name, direction, field, type)
    add_field = ''
    indent = ''
    # If the field's optional, add the logic
    if(field.is_optional)
      indent = '  '
      field1 = field.optional_field.is_a?(String) ? "get_#{field.optional_field}_value_#{direction}(tvb)" : field.optional_field.to_s
      field2 = field.optional_value.is_a?(String) ? "get_#{field.optional_value}_value_#{direction}(tvb)" : field.optional_value.to_s
      add_field += "    if(#{field1} #{field.optional_operator} #{field2}) {\n"
    end

    case type
      when :uint8, :uint16, :uint32
        add_field += "#{indent}    proto_tree_add_uint(#{@protocol_abbrev}_tree, hf_#{name}_#{direction}, tvb, get_#{name}_position_#{direction}(tvb), get_#{name}_length_#{direction}(tvb), get_#{name}_value_#{direction}(tvb));\n"
      when :string, :ntstring, :lpstring, :untstring
        add_field += "#{indent}    proto_tree_add_string(#{@protocol_abbrev}_tree, hf_#{name}_#{direction}, tvb, get_#{name}_position_#{direction}(tvb), get_#{name}_length_#{direction}(tvb), get_#{name}_value_#{direction}(tvb));\n"
      else
        throw :unknown_type
    end

    if(field.is_optional)
      add_field += "    }\n"
    end

    return add_field
  end

  def get_variable_declaration(name, direction, field)
    return "static int hf_#{name}_#{direction} = -1;"
  end

  def get_length_function(name, direction, field, type)
    length_function = "guint32 get_#{name}_length_#{direction}(tvbuff_t *tvb) {\n"
    case type
      when :uint8
        length_function += "  TVB_WARNING_HACK\n"
        length_function += "  return 1;\n"
      when :uint16
        length_function += "  TVB_WARNING_HACK\n"
        length_function += "  return 2;\n"
      when :uint32
        length_function += "  TVB_WARNING_HACK\n"
        length_function += "  return 4;\n"
      when :string
        length_function += "  TVB_WARNING_HACK\n"
        length_function += "  return #{field.length.is_a?(String) ? "get_#{name}_value_#{direction}(tvb)" : field.length};\n"
      when :ntstring
        length_function += "  return tvb_strsize(tvb, get_#{name}_position_#{direction}(tvb));\n";
      when :lpstring
        length_function += "  return tvb_get_guint8(tvb, get_#{name}_position_#{direction}(tvb)) + 1;\n";
      when :untstring
        length_function += "  gint length;\n";
        length_function += "  tvb_get_ephemeral_unicode_stringz(tvb, get_#{name}_position_#{direction}(tvb), &length, 0);\n";
        length_function += "  return (length + 1);\n";
      else
        throw :unknown_type
    end

    length_function += "}\n"

    return length_function
  end

  def get_position_function(name, direction, field, type, structure)
    # Declare the function
    position_string = "guint32 get_#{name}_position_#{direction}(tvbuff_t *tvb) {\n"

    # Get the base position (either as a string or an integer)
    position_string += "  guint32 position;\n"
    if(field.offset.is_a?(String))
      position_string += "  position = get_#{field.offset}_value_#{direction}(tvb);\n"
    else
      position_string += "  position = #{field.offset};\n"
    end

    # Get the parent field
    parent = structure.get_parent(field)
    if(parent)
      position_string += "  position = position + get_#{parent.name}_position_#{direction}(tvb) + get_#{parent.name}_length_#{direction}(tvb);\n"
    end

    position_string += "  TVB_WARNING_HACK\n"

    # Return the value
    position_string += "  return position;\n"

    # End the function
    position_string += "}";

    return position_string
  end

  def get_value_function(name, direction, field, type)
    value_string = Field::TYPES_C[field.type] + " get_#{name}_value_#{direction}(tvbuff_t *tvb) {\n"
    case Field::TYPES[field.type]
      when :uint8
        value_string += "  return tvb_get_guint8(tvb, get_#{name}_position_#{direction}(tvb));\n"
      when :uint16
        if(Field::ENDIANS[field.endian] == :little_endian)
          value_string += "  return tvb_get_letohs(tvb, get_#{name}_position_#{direction}(tvb));\n"
        else
          value_string += "  return tvb_get_ntohs(tvb, get_#{name}_position_#{direction}(tvb));\n"
        end
      when :uint32
        if(Field::ENDIANS[field.endian] == :little_endian)
          value_string += "  return tvb_get_letohl(tvb, get_#{name}_position_#{direction}(tvb));\n"
        else
          value_string += "  return tvb_get_ntohl(tvb, get_#{name}_position_#{direction}(tvb));\n"
        end
      when :string
        if(field.length.is_a?(String))
          value_string += "  return tvb_get_ephemeral_string(tvb, get_#{name}_position_#{direction}(tvb), get_#{field.length}_value_#{direction}(tvb));\n"
        else
          value_string += "  return tvb_get_ephemeral_string(tvb, get_#{name}_position_#{direction}(tvb), #{field.length});\n"
        end
      when :ntstring
        value_string += "  return tvb_get_ephemeral_stringz(tvb, get_#{name}_position_#{direction}(tvb), NULL);\n";
      when :lpstring
        value_string += "  return tvb_get_ephemeral_string(tvb, get_#{name}_position_#{direction}(tvb) + 1, tvb_get_guint8(tvb, get_#{name}_position_#{direction}(tvb)));\n"
      when :untstring
        value_string += "  return tvb_get_ephemeral_unicode_stringz(tvb, get_#{name}_position_#{direction}(tvb), NULL, 0);\n";
      else
        throw :unknown_type
    end

    value_string += "}\n"

    return value_string 
  end
end

