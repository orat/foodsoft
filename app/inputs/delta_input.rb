# encoding: utf-8

class DeltaInput < SimpleForm::Inputs::StringInput
  # for now, need to pass id or it won't work
  def input
    classes = 'delta-input input-prepend input-append'
    @input_html_options[:data] ||= {}
    @input_html_options[:data][:delta] ||= 1
    @input_html_options[:autocomplete] ||= 'off'
    # TODO get generated id, don't know how yet - `add_default_name_and_id_for_value` might be an option

    # when min == max it is essentially uneditable
    if @input_html_options[:data][:min] && @input_html_options[:data][:max] &&
         @input_html_options[:data][:min] == @input_html_options[:data][:max]
      @input_html_options[:disabled] = 'disabled'
      classes += ' delta-input-disabled' # for easier styling
    end

    template.content_tag :div, class: classes do
      delta_button('−', -1) + super + delta_button('+', 1)
    end
  end
  #template.button_tag('−', type: :submit, data: {decrement: @input_html_options[:id]}, tabindex: -1, class: 'btn') +

  private

  def delta_button(title, direction)
    data = { (direction>0 ? 'increment' : 'decrement') => @input_html_options[:id] }
    delta = direction * @input_html_options[:data][:delta]
    template.button_tag(title, type: :button, name: 'delta', value: delta, data: data, tabindex: -1, class: 'btn')
  end
end
