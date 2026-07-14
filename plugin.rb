# frozen_string_literal: true
# name: discourse-allow-pm-to-staff
# about: Allow pms to staff even if PMs are otherwise not allowed
# version: 0.2
# authors: pfaffman

after_initialize do
  add_to_class(:guardian, :old_can_send_private_message?) do |target, notify_moderators: false|
    # copied from guardian.rb
    target_is_user = target.is_a?(User)
    target_is_group = target.is_a?(Group)
    from_system = @user.is_system_user?

    # Must be a valid target
    return false if !(target_is_group || target_is_user)

    # Users can send messages to certain groups with the `everyone` messageable_level
    # even if they are not in personal_message_enabled_groups
    group_is_messageable = target_is_group && Group.messageable(@user).where(id: target.id).exists?

    # User is authenticated and can send PMs, this can be covered by trust levels as well via AUTO_GROUPS
    (can_send_private_messages?(notify_moderators: notify_moderators) || group_is_messageable) &&
      # User disabled private message
      (is_staff? || target_is_group || target.user_option.allow_private_messages) &&
      # Can't send PMs to suspended users
      (is_staff? || target_is_group || !target.suspended?) &&
      # Check group messageable level
      (from_system || target_is_user || group_is_messageable || notify_moderators) &&
      # Silenced users can only send PM to staff
      (!is_silenced? || target.staff?)
  end
  add_to_class(:guardian, :can_send_private_messages?) do |notify_moderators: false|
    from_system = @user.is_system_user?
    from_bot = @user.bot?

    # User is authenticated
    authenticated? &&
      # User can send PMs, this can be covered by trust levels as well via AUTO_GROUPS
      (
        is_staff? || from_bot || from_system ||
          (@user.in_any_groups?(SiteSetting.personal_message_enabled_groups_map)) ||
          notify_moderators || SiteSetting.allow_pm_to_staff_enabled
      )
  end

  # `**` swallows keywords core adds later (e.g. private_message_context in 2026.7)
  add_to_class(:guardian, :can_send_private_message?) do |target, notify_moderators: false, **|
    return false unless authenticated?
    target_is_user = target.is_a?(User)
    target_is_group = target.is_a?(Group)
    from_system = @user.is_system_user?
    current_user_can_send =
      current_user.in_any_groups?(SiteSetting.personal_message_enabled_groups_map)

    # Must be a valid target
    return false if !(target_is_group || target_is_user)

    # Users can send messages to certain groups with the `everyone` messageable_level
    # even if they are not in personal_message_enabled_groups
    group_is_messageable = target_is_group && Group.messageable(@user).where(id: target.id).exists?
    receiving_group =
      (
        if target_is_group
          false
        else
          allowed_groups_count =
            (target.groups.pluck(:name) & SiteSetting.allow_pm_allowed_pm_groups.split("|")).length
          (allowed_groups_count > 0)
        end
      )

    # User is authenticated and can send PMs, this can be covered by trust levels as well via AUTO_GROUPS
    (can_send_private_messages?(notify_moderators: notify_moderators) || group_is_messageable) &&
      # User disabled private message
      (
        current_user_can_send || is_staff? || target_is_group ||
          (target.user_option.allow_private_messages && receiving_group)
      ) &&
      # Can't send PMs to suspended users
      (is_staff? || target_is_group || !target.suspended?) &&
      # Check group messageable level
      (from_system || target_is_user || group_is_messageable || notify_moderators) &&
      # Silenced users can only send PM to staff
      (!is_silenced? || target.staff?)
  end
end
