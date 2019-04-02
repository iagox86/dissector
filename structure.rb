class Structure
  def initialize()
    @fields = {}
  end

  def get_field(name)
    if(name.is_a?(String))
      return @fields[name]
    else
      return name
    end
  end

  def get_parent(field)
    # Make sure we have a field and not a field name
    field = get_field(field)

    return field.parent == nil ? nil : get_field(field.parent)
  end

  # If it's an integer, return it as a proper Fixnum. If it's a string,
  # return it as such. 
  def number_or_field(value)
    if(value =~ /^[0-9]+$/)
      return value.to_i
    else
      return value
    end
  end

  def delete_field(field)
    # Make sure we have a field and not a field name
    field = get_field(field)
    if(!field.nil?)
      @fields.delete(field.name)
    end
  end

  def delete_callback(field)
    delete_field(field)
    return true
  end

  # Where in the packet defined by 'data' is the named field located?
  def get_position(data, field)
    # Make sure we have a field and not a field name
    field = get_field(field)

    # Get the offset value
    position = field.offset
    #MessageBox.new("Offset for %s = %s" % [field.name, field.offset]).go

    # The offset can be a reference to another field or an integer
    if(position.is_a?(String))
      position = get_field_value(data, get_field(position))
    end

    # If the field has a parent, add it to the position
    parent = get_parent(field)
    if(parent)
      position = position + get_position(data, parent) + get_field_size(data, parent)
    end

    return position
  end

  # Loop through all fields in the data and find the ones with the given value.
  # Return a list of the fields' names
  def get_fields_with_value(data, value)
    result = []

    each_field() do |name, field|
      if(get_field_value(data, field) == value)
        result << name
      end
    end

    return result
  end

  # Loop over each field
  def each_position_length_field(data, show_optional = false)
    each_field() do |name, field|
      if(show_optional == true || should_display_field(data, field))
        position = get_position(data, field)
        yield position, get_field_size(data, @fields[name]), @fields[name]
      end
    end
  end

  def each_field()
    fields = @fields.values().sort() do |a, b| a.order <=> b.order end

    fields.each do |field|
      yield field.name, field
    end
  end

  def get_field_at(data, position)
    each_position_length_field(data) do |field_position, field_size, field|
      if(position >= field_position && position < field_position + field_size)
        return field
      end
    end

    return nil
  end

  def can_create_field(data, position, type)
    field_size = Field.estimate_field_size(data, type, position)

    # Check if it goes off the end
    if(Field.too_long(data, position, field_size))
      return false
    end

    # Check if it runs into another field
    position.upto(position + field_size - 1) do |i|
      if(!get_field_at(data, i).nil?)
        return false
      end
    end

    return true
  end

  # Return a list of all indexes in data that have two or more fields
  def get_overlapping_indexes(data)
    indexes = {}
    each_position_length_field(data) do |position, length, field|
      position.upto(position + length - 1) do |i|
        if(indexes[i].nil?)
          indexes[i] = 1
        else
          indexes[i] += 1
        end
      end
    end

    # I know there's a better way to do this, but I don't know what it is
    overlaps = []
    indexes.each_pair() do |i, v|
      if(v > 1)
        overlaps << i
      end
    end

    return overlaps
  end

  def each_field_with_value(data, value, show_optional = false)
    each_position_length_field(data, show_optional) do |position, length, field|
      if(get_field_value(data, field) == value)
        yield field.name
      end
    end
  end

  # Make sure the field isn't in the same heirarchy (to prevent infinite recursion)
  def in_hierarchy(name, potential_parent)
    # If there's no field, we don't have to worry about looping
    if(name.nil?)
      return false
    end

    # If there's no parent, we're safe
    if(potential_parent == nil || potential_parent.is_a?(Fixnum))
      return false
    end

    # If it equals the parent, we're hosed
    if(name == potential_parent)
      return true
    end

    parent = @fields[potential_parent]
    return in_hierarchy(name, parent.parent) || in_hierarchy(name, parent.offset)

  end

  # Get a hash of all numeric values from the packet
  def get_numeric_values(data)
    values = {}
    each_position_length_field(data) do |position, length, field|
      value = get_field_value(data, field)
      if(value.is_a?(Fixnum))
        values[field.name] = value
      end
    end

    return values
  end

  def get_possible_references_to(data, field, offset)
    # Make sure we have a field and not a field name
    field = get_field(field)

    references = []

    # Start with the easiest case - just the offset from the beginning
    references << { :parent => nil, :offset => offset, :text => "%d bytes from the beginning" % offset }

    # Next, check if any fields have the proper offset from the start of the packet
    each_field_with_value(data, offset) do |field_name|
      if(!in_hierarchy(field.name, field_name))
        references << { :parent => nil, :offset => field_name, :text => "<%s> bytes from the beginning" % field_name }
      end
    end

    # Next, loop over all the fields before our current field
    each_position_length_field(data) do |position, length, parent_field|
      if(!in_hierarchy(field.name, parent_field.name))
        # A static offset from the beginning of that field
        offset_from_parent = offset - position - get_field_size(data, parent_field)
        if(offset_from_parent >= 0)
          offset_string = (offset_from_parent == 0) ? 'immediately' : ("%d bytes" % offset_from_parent)
          references << { :parent => parent_field.name, :offset => offset_from_parent, :text => "%s after %s" % [offset_string, parent_field.name] }
        else
          offset_string = (offset_from_parent == 0) ? 'immediately' : ("%d bytes" % -offset_from_parent)
          references << { :parent => parent_field.name, :offset => offset_from_parent, :text => "%s before %s" % [offset_string, parent_field.name] }
        end
  
        # Check if any fields match the offset
        each_field_with_value(data, offset_from_parent) do |field_name|
          if(!in_hierarchy(field.name, field_name))
            references << { :parent => parent_field.name, :offset => field_name, :text => "<%s> bytes after %s" % [field_name, parent_field.name] }
          end
        end
      end
    end

    return references
  end

  def edit_field(data, position, type = nil, endian = nil)
    # Check if we already have a field there and create it if we don't
    field = get_field_at(data, position)
    if(field.nil?)
      field = Field.new(position, type, endian)
    end

    # Don't let them change fields with children - it's not worth the trouble
    children = get_children(field)
    if(!children.nil? && children.size > 0)
      MessageBox.new("Sorry, you can't edit fields that other fields depend on. The following fields depend on #{field.name}:\n" + children.join("\n")).go
      return
    end

    # Temporarily remove the old name
    delete_field(field.name) if(!field.name.nil?)

    good_name = false
    while !good_name do
      field.name = Textbox.new(field.name).prompt("Please enter a name (letter, num, _) --> ")
      return if(field.name.nil?)

      good_name = true
      if(!field.name.match(/^[a-zA-Z][a-zA-Z0-9_]*$/))
        good_name = false
        MessageBox.new("Names can only contain letters, numbers, and underscore, and must start with a letter!").go
      end
      if(get_field(field.name))
        MessageBox.new("There's already a field called #{field.name}!").go
        good_name = false
      end
    end

    begin
      field.type   = Listbox.new(field.type,   Field::TYPES).prompt("Please select a type")
      return if(field.type.nil?)

      field.endian = Listbox.new(field.endian, Field::ENDIANS).prompt("Please select a byte order")
      return if(field.endian.nil?)

      field.color = ColorChooser.new(field.color).prompt("Please select a color --> ")
      return if(field.color.nil?)

      # Figure out what parents/offsets are legal
      references = get_possible_references_to(data, field, position)
      choices = []
      index = -1
      references.each do |reference| # each reference has :parent :offset :text
        if(reference[:offset] == field.offset && reference[:parent] == field.parent)
          index = choices.size
        end
        choices << { :name => reference[:text], :value => reference }
      end
      if(index == -1)
        if(field.parent.nil?)
          index = field.offset.nil? ? 0 : field.offset
        else
          index = 0
        end
      end
   
      choice = number_or_field(Listbox.new(index, choices, true).prompt("Please choose an offset:"))
      return if(choice.nil?)
      if(choice.is_a?(Fixnum))
        field.parent = nil
        field.offset = choice
      else
        field.parent = choice[:parent]
        field.offset = choice[:offset]
      end
   
      # If the field has a user-configurable length, request it
      if(Field.should_request_length(field.type))
        values = get_numeric_values(data)
        choices = []
        i = 0
        index = field.length.to_i
        values.each_pair do |k, v|
          choices << { :value => k, :name => ("%s (%d byte%s)" % [k, v, v == 1 ? '' : 's'])}
          if(k == field.length)
            index = i
          end
          i += 1
        end
        field.length = number_or_field(Listbox.new(index, choices, true).prompt("Please select a length:"))
        return if(field.length.nil?)
      end
   
      # Check if the field is optional - if it is, get the criteria
      if(@fields.size > 0)
        field.is_optional = Listbox.new(field.is_optional ? 1 : 0, [{:name => 'No', :value => false}, {:name => 'Yes', :value => true}]).prompt("Is this field optional?");
        return if(field.is_optional.nil?)
        if(field.is_optional)
          # Get the comparison field
          values = get_numeric_values(data)
          choices = []
          choice = field.optional_field.to_i
          values.each_pair do |k, v|
            if(k == field.optional_field)
              choice = choices.length
            end
            choices << { :value => k, :name => ("%s (%d)" % [k, v])}
          end
          field.optional_field = number_or_field(Listbox.new(choice, choices, true).prompt("Please select the comparison value:"))
          return if(field.optional_field.nil?)
   
          # Get the comparison operator
          choices = []
          choice = 0
          Field::OPERATORS.each do |o|
            if(o == field.optional_operator)
              choice = choices.length
            end
            choices << { :value => o, :name => o }
          end
          field.optional_operator = Listbox.new(choice, choices).prompt("Please select the comparison operator");
          return if(field.optional_operator.nil?)
   
          # Get the comparison value
          values = get_numeric_values(data)
          choices = []
          choice = field.optional_value.to_i
          values.each_pair do |k, v|
            if(k == field.optional_value)
              choice = choices.length
            end
            choices << { :value => k, :name => ("%s (%d)" % [k, v])}
          end
          field.optional_value = number_or_field(Listbox.new(choice, choices, true).prompt("Please select the comparison value:"))
          return if(field.optional_value.nil?)
        end
      end
    ensure
      # Ensure the the field is always re-added
      @fields[field.name] = field
    end
  end

  # Give the user a list of all fields, and let them choose which one to edit
  def choose_edit_field(data)
    choices = []
    each_position_length_field(data, true) do |position, length, field|
      this_value = get_field_value(data, field)
      choices << {:value => field.name, :name => "%s => %s" % [field.name, this_value]}
    end

    list = Listbox.new(nil, choices)
    list.add_key_callback(?d, method(:delete_callback))
    field_to_edit = list.prompt("Select a field to edit (use pgup/pgdn to re-order):");

    # Put the fields in order in case they re-ordered them
    each_field() do |name, field|
      field.order = list.get_index(name)
    end

    # If they pressed 'escape', don't save it
    if(field_to_edit.nil?)
      return
    end

    # We have the name, we want the position
    position = get_position(data, field_to_edit)
    edit_field(data, position)
  end

  def get_field_size(data, field)
    # Make sure we have a field and not a field name
    field = get_field(field)
    max_length = data.length - get_position(data, field)

    if(!field.type.is_a?(Fixnum))
      MessageBox.new(field.inspect.to_s).go
    end

    case Field::TYPES[field.type]
      when :uint8
        return 1
      when :uint16
        return 2
      when :uint32
        return 4
      when :ntstring
        length = 0
        pos = get_position(data, field)
        while(Field.get_uint8(data, pos + length) != 0)
          length = length + 1
          if(Field.too_long(data, pos, length))
            return [max_length, length].min
          end
        end
        return length + 1
      when :lpstring
        pos = get_position(data, field)
        return [max_length, Field.get_uint8(data, pos) + 1].min
      when :untstring
        length = 0
        pos = get_position(data, field)
        # Note: Endian doesn't matter here since we're looking for 0x0000
        while(Field.get_uint16(data, :little_endian, pos + length) != 0)
          length = length + 2
          if(Field.too_long(data, pos, length))
            return [max_length, length].min
          end
        end
        return length + 2
      when :string
        return [max_length, get_field_value(data, field.length)].min
      else
        throw :unknown_type
    end
  end

  def get_field_value(data, field)
    # If it's a numeric value, not a field, just return it
    # (this simplifies a bunch of code)
    if(field.is_a?(Fixnum))
      return field
    end

    # If the field doesn't meet the pre-requisites for display, it's nil
    if(!should_display_field(data, field))
      return nil
    end

    # Make sure we have a field and not a field name
    field = get_field(field)

    size = get_field_size(data, field)
    pos  = get_position(data, field)
    if(Field.too_long(data, pos, size))
      return nil
    end

    case Field::TYPES[field.type]
    when :uint8
      return Field.get_uint8(data, pos)
    when :uint16
      return Field.get_uint16(data, field.endian, pos)
    when :uint32
      return Field.get_uint32(data, field.endian, pos)
    when :ntstring
      str = ''
      while(Field.get_uint8(data, pos + str.length) != 0)
        str = str + Field.get_char(data, pos + str.length)
        if(Field.too_long(data, pos, str.length))
          return nil
        end
      end
      return str
    when :lpstring
      return Field.get_bytes(data, size, pos + 1)
    when :untstring
      str = ''
      # Note: Endian doesn't matter here since we're looking for 0x0000
      # Note: We're faking unicode right now - see if we can do it right
      while(Field.get_uint16(data, :little_endian, pos + (str.length * 2)) != 0)
        str = str + Field.get_char(data, pos + (str.length * 2))
        if(Field.too_long(data, pos, str.length * 2))
          return length
        end
      end
      return str
    when :string
      #return Field.get_bytes(data, get_field_value(data, @fields[field.length]), pos)
    else
      throw :unknown_type
    end
  end

  def should_display_field(data, field)
    # Make sure we have a field and not a field name
    field = get_field(field)

    if(!field.is_optional)
      return true;
    end

    field1 = get_field_value(data, field.optional_field)
    field2 = get_field_value(data, field.optional_value)

    case field.optional_operator
      when '=='
        return field1 == field2
      when '!='
        return field1 != field2
      when '&'
        return (field2 & field2) != 0
      when '|'
        return (field2 | field2) != 0
      when '^'
        return (field2 ^ field2) != 0
      when '>'
        return field1 > field2
      when '>='
        return field1 >= field2
      when '<'
        return field1 < field2
      when '<='
        return field1 <= field2
      else throw :unknown_operator
    end
  end

  def get_children(field)
    # Make sure we have a field and not a field name
    field = get_field(field)
    return nil if(field.nil? || field.name.nil?)

    name = field.name
    children = []
    each_field() do |_, field|
      if(field.parent == name || field.offset == name || field.length == name || field.optional_field == name || field.optional_value == name)
        children << field.name
      end
    end

    return children
  end

  # Update any pointers to the old name
  def rename_field(old, new)
    old_field = get_field(old)
    @fields.delete(old)

    old_field.name = new
    @fields[old_field.name] = old_field

    each_field() do |name, field|
      field.parent         = new if(field.parent == old)
      field.offset         = new if(field.offset == old)
      field.length         = new if(field.length == old)
      field.optional_field = new if(field.optional_field == old)
      field.optional_value = new if(field.optional_value == old)
    end
  end
end

