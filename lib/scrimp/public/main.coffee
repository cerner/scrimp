Scrimp = {}

default_request = ->
  request =
    service: (service for service of Scrimp.services)[0]
    protocol: (protocol for protocol of Scrimp.protocols)[0]
    host: "localhost"
    port: 9000
    args: {}
  request.function = (func for func of Scrimp.services[request.service])[0]
  request

load_services = (data) ->
  Scrimp.services = data
  for service, functions of Scrimp.services
    option = $('<option>').val(service).text(service)
    $('select.service-field').append(option)

load_structs = (data) ->
  Scrimp.structs = data

load_protocols = (data) ->
  Scrimp.protocols = data
  for protocol of Scrimp.protocols
     option = $('<option>').val(protocol).text(protocol)
     $('select.protocol-field').append(option)

service_changed = ->
  $('select.function-field').empty()
  service = Scrimp.services[$('select.service-field').val()]
  if service
    for func, desc of Scrimp.services[$('select.service-field').val()]
      option = $('<option>').val(func).text(func)
      $('select.function-field').append(option)
  function_changed()

type_info = (info) ->
  $type = $('<span>').addClass('type-info')
  if info.type == 'STRUCT'
    $type.text(info.class)
  else
    $type.text(info.type)

build_input = (info, value) ->
  switch info.type
    when "BOOL"
      $input = $('<input type="checkbox">').addClass('bool-field')
      if info.default != undefined then $input.prop('checked', info.default)
      if value != undefined then $input.prop('checked', value)
    when "DOUBLE"
      $input = $('<input type="text">').addClass('double-field')
      if info.default != undefined then $input.val(info.default)
      if value != undefined then $input.val(value)
    when "BYTE", "I16", "I32", "I64"
      if info.enum
        $input = $('<select>').addClass('enum-field')
        for constval, name of info.enum
          $input.append $('<option>').val(name).text('' + constval + ' = ' + name)
        if info.default != undefined then $input.val(info.enum[info.default])
        if value != undefined
          if isNaN(value)
            $input.val(value)
          else
            $input.val(info.enum[value])
      else
        $input = $('<input type="text">').addClass('int-field')
        if info.default != undefined then $input.val(info.default)
        if value != undefined then $input.val(value)
    when "STRING"
      $input = $('<input type="text">').addClass('string-field')
      if info.default != undefined then $input.val(info.default)
      if value != undefined then $input.val(value)
    when "STRUCT"
      # TODO defaults
      $input = $('<ul>').addClass('struct-field')
      populate_struct $input, Scrimp.structs[info.class], value
    when "LIST", "SET"
      # TODO defaults
      $input = $('<ul>').addClass('list-field')
      add_element = (element) ->
        $li = $('<li>').addClass('list-field-element')
        $del = $('<a>').attr('href', '#').addClass('del').text('del').click ->
          $li.remove()
        $li.append($del)
        $li.append(type_info(info.element))
        $li.append(build_input(info.element, element))
        $input.children('li').last().before($li)
      $add = $('<a>').attr('href', '#').addClass('add').text('add').click -> add_element(element)
      $input.append($('<li>').append($add))
      if value
        for element in value
          add_element(element)
    when "MAP"
      # TODO defaults
      $input = $('<ul>').addClass('map-field')
      add_kv = (key, value) ->
        $li = $('<li>').addClass('map-field-entry')
        $del = $('<a>').attr('href', '#').addClass('del').text('del').click ->
          $li.remove()
        $li.append($del)
        $key = $('<div>').addClass('map-field-key')
        $key.append($('<label>').addClass('map-field-label').text('key'))
        $key.append(type_info(info.key))
        $key.append(build_input(info.key, key))
        $li.append($key)
        $val = $('<div>').addClass('map-field-value')
        $val.append($('<label>').addClass('map-field-label').text('val'))
        $val.append(type_info(info.value))
        $val.append(build_input(info.value, value))
        $li.append($val)
        $input.children('li').last().before($li)
      $add = $('<a>').attr('href', '#').addClass('add').text('add').click -> add_kv(undefined, undefined)
      $input.append($('<li>').append($add))
      if value
        for pair in value
          add_kv(pair[0], pair[1])
  $input.addClass('request-field')

populate_struct = ($struct, fields, values) ->
  if !values then values = {}
  for name, info of fields
    value = values[name]
    $include = $('<input type="checkbox">').addClass('include-field').prop('checked', value != undefined)
    $type = type_info(info)
    $label = $('<label>').addClass('struct-value').text(name)
    $input = build_input info, value
    $li = $('<li>').addClass('struct-field-entry')
    if info.optional then $li.append($include)
    $struct.append $li.append($label).append($type).append($input)

function_changed = ->
  $('.args-field').empty()
  populate_struct $('.args-field'),
                  Scrimp.services[$('select.service-field').val()][$('select.function-field').val()].args,
                  Scrimp.last_json.args

load_structured_request = ->
  try
    Scrimp.last_json = parsed = JSON.parse($('.request-json').val())
  catch ex
    return confirm("Invalid JSON; changes will be lost!")

  if not (parsed.service of Scrimp.services)
    return confirm("Invalid service; changes will be lost!")
  if not (parsed.function of Scrimp.services[parsed.service])
    return confirm("Invalid function; changes will be lost!")

  $('select.service-field').val(parsed.service)
  service_changed()
  $('select.function-field').val(parsed.function)
  function_changed()
  $('select.protocol-field').val(parsed.protocol)
  $('input.host-field').val(parsed.host)
  $('input.port-field').val(parsed.port)
  true

build_json_for_field = ($el) ->
  if $el.hasClass('struct-field')
    json = {}
    $el.children('li').each (_, li) ->
      $li = $(li)
      $include = $li.children('.include-field')
      if !$include.size() || $include.prop('checked')
        json[$li.children('label.struct-value').text()] = build_json_for_field($li.children('.request-field'))
        null
  else if $el.hasClass('bool-field')
    json = (if $el.prop('checked') then true else false)
  else if $el.hasClass('double-field')
    json = parseFloat($el.val())
  else if $el.hasClass('int-field')
    json = parseInt($el.val())
  else if $el.hasClass('string-field') || $el.hasClass('enum-field')
    json = $el.val()
  else if $el.hasClass('list-field')
    json = []
    $el.children('.list-field-element').each (_, li) ->
      $li = $(li)
      json.push(build_json_for_field($li.children('.request-field')))
  else if $el.hasClass('map-field')
    json = []
    $el.children('.map-field-entry').each (_, li) ->
      $li = $(li)
      json.push([build_json_for_field($li.children('.map-field-key').children('.request-field')),
                 build_json_for_field($li.children('.map-field-value').children('.request-field'))])
  json

build_raw_request = ->
  request =
    service: $('select.service-field').val()
    function: $('select.function-field').val()
    protocol: $('select.protocol-field').val()
    host: $('input.host-field').val()
    port: $('input.port-field').val()
    args: build_json_for_field($('.args-field'))
  request

load_raw_request = ->
  request = build_raw_request()
  $('.request-json').val(JSON.stringify(request, null, 2))

build_response_element = (value, info) ->
  switch info.type
    when "BOOL"
      $('<span>').addClass('value-bool').text(value ? "true" : "false")
    when "BYTE", "I16", "I32", "I64", "DOUBLE"
      if info.enum # totally untested
        $constval = null
        for constval, name of info.enum
          if name == value
            $constval = $('<span>').addClass('value-enum-const').text(constval)
        $name = $('<span>').addClass('value-enum-name').text(value)
        $('<span>').addClass('value-enum').append($constval).append(' = ').append($name)
      else
        $('<span>').addClass('value-number').text(value)
    when "STRING"
      $('<span>').addClass('value-string').text(value)
    when "STRUCT"
      $ul = $('<ul>').addClass('value-struct')
      for name, content of value
        $li = $('<li>').addClass('value-struct-entry')
        $name = $('<span>').addClass('value-struct-entry-name').text(name)
        $li.append $name
        $li.append build_response_element(content, Scrimp.structs[info.class][name])
        $ul.append $li
      $ul
    when "LIST", "SET"
      $ul = $('<ul>').addClass('value-list')
      for element in value
        $li = $('<li>').addClass('value-list-element')
        $li.append build_response_element(element, info.element)
        $ul.append $li
      $ul
    when "MAP"
      $ul = $('<ul>').addClass('value-map')
      for pair in value
        $li = $('<li>').addClass('value-map-entry')
        $key = $('<div>').addClass('value-map-key').append($('<span>').addClass('map-field-label').text('key'))
        $key.append build_response_element(pair[0], info.key)
        $li.append $key
        $value = $('<div>').addClass('value-map-value').append($('<span>').addClass('map-field-label').text('val'))
        $value.append build_response_element(pair[1], info.value)
        $li.append $value
        $ul.append $li
      $ul
    when "VOID"
      $('<span>').addClass('value-void').text('VOID (note: for oneway methods, success merely indicates the message was sent; it may not have been received or recognized)')

populate_structured_response = (request, response) ->
  $details = $('.response-details')
  $details.empty()
  if response.return != undefined
    $('.response-error').hide()
    $('.response-success').show()
    $details.append build_response_element(response.return, Scrimp.services[request.service][request.function].returns)
  else
    $('.response-success').hide()
    for err, details of response # there's only one. this is awkward
      $('.response-error').text(err)
      if err == 'Thrift::ApplicationException'
        $details.append($('<p>').text(details.type))
        $details.append($('<pre>').text(details.message))
      else
        $detailsList = $('<dl>')
        for field, value of details
          $detailsList.append($('<dt>').text(field))
          $detailsList.append($('<dd>').text(value))
        $details.append($detailsList)
    $('.response-error').show()

$ ->
  $.ajax
    success: load_services
    url: '/services'
    async: false # yeah yeah it's silly get over it
  $.ajax
    success: load_structs
    url: '/structs'
    async: false
  $.ajax
    success: load_protocols
    url: '/protocols'
    async: false
  $('select.service-field').change(service_changed)
  $('select.function-field').change(function_changed)
  $('.request-json').val(JSON.stringify(default_request(), null, 2))
  $('.show-raw-request').click ->
    load_raw_request()
    $('.structured-request').hide()
    $('.raw-request').show()
  $('.show-structured-request').click ->
    if load_structured_request()
      $('.raw-request').hide()
      $('.structured-request').show()
  $('.show-structured-request').show()
  $('.invoke').click ->
    if $('.raw-request:hidden').size()
      load_raw_request()
    request = $('.request-json').val()
    $.post $('.request-form').attr('action'),
           request,
           (data) ->
             populate_structured_response JSON.parse(request), data
             $('.response-json').text(JSON.stringify(data, null, 2))
             $('.response').show()
    false
  $('.show-raw-response').click ->
    $('.structured-response').hide()
    $('.raw-response').show()
  $('.show-structured-response').click ->
    $('.raw-response').hide()
    $('.structured-response').show()
  $('.show-structured-request').click()
