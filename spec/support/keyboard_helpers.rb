# Presses keys on the page the way a keyboard does, through WebDriver key actions to the focused element.
# Element send_keys is not used: chromedriver turns its characters into key events through the host's X11
# keymap whenever DISPLAY is set, and under WSLg that yields keydowns with an empty `code`, which the live
# protocol console ignores. Key actions carry the key itself, so `code` is filled on any host.
#
#   press_keys("1", "n", :return)  # one key after another; :return is Enter, :enter is NumpadEnter
#   press_keys([ :shift, "d" ])    # modifiers held while the rest of the array is pressed
module KeyboardHelpers
  MODIFIERS = %i[shift control alt meta command].freeze

  def press_keys(*keys)
    keys.each do |key|
      action = page.driver.browser.action
      key.is_a?(Array) ? press_chord(action, key) : action.send_keys(key)
      action.perform
    end
  end

  private

  def press_chord(action, keys)
    modifiers, rest = keys.partition { |key| MODIFIERS.include?(key) }
    modifiers.each { |modifier| action.key_down(modifier) }
    action.send_keys(*rest)
    modifiers.reverse_each { |modifier| action.key_up(modifier) }
  end
end

RSpec.configure do |config|
  config.include KeyboardHelpers, type: :system
end
