# FIXME: Refactor
class SmsInvitationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  skip_before_action :authenticate_user!
  before_action :person
  def create
    save_twilio_message # see receive_text_controller

    send_error_notification && return unless @person
    PaperTrail.whodunnit = @person # auditing
    Rails.logger.info "#{person.full_name}: #{message}"
    @person.verified = 'Verified'
    @person.save

    # FIXME: this if else bundle needs a refactor badly.
    if remove?
      do_remove
    elsif confirm? # confirmation for the days invitations
      do_confirm
    elsif cancel?
      do_cancel
    elsif calendar?
      # ten upcoming in the next 100 days. excessive.
      invitations = person.invitations.upcoming(100).limit(10).to_a
      ::InvitationReminderSms.new(to: @person, invitations: invitations).send
    end
    # twilio wants an xml response.
    render text: '<?xml version="1.0" encoding="UTF-8" ?><Response></Response>'
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

    def message
      str = sms_params[:Body].force_encoding('utf-8').encode
      Emoji.replace_unicode_moji_with_name(str)
    end

    def get_numbers_or_all
      numbers = message.map { |x| x[/\d+/] }
      if all?
        :all
      elsif numbers.blank?
        false
      else
        numbers
      end
    end

    def all?
      message.downcase =~ /^all$/
    end

    def set_person
      @person ||= Person.find_by(phone_number: sms_params[:From])
    end

    def send_error_notification
      # awkward, yes, but see application_sms to understand why
      phone_struct = Struct.new(:phone_number).new(sms_params[:From])
      ::InvalidOptionSms.new(to: phone_struct).send
      if @person
        invs = @person.invitations.upcoming(100).limit(9)
        ::InvitationReminderSms.new(to: @person, invitations: invs)
      end
      render text: '<?xml version="1.0" encoding="UTF-8" ?><Response></Response>'
    end

    # perhaps a fuzzy_text here?
    def confirm?
      if message.downcase =~ /^ok|confirm|yes$/
        session[:confirm] = true
      elsif session[:confirm] # in a confirm session
        true
      else
        sessions[:confirm] =  false
      end
    end

    def cancel? # can't use the word "Cancel!!!"
      #https://support.twilio.com/hc/en-us/articles/223134027-Twilio-support-for-STOP-BLOCK-and-CANCEL-SMS-STOP-filtering-
      if message.downcase =~ /^no|nah|can\'t$/
        session[:cancel] = true
      elsif session[:cancel] # in a cancel session
        true
      else
        sessions[:cancel] =  false
      end
    end

    # can't use the word info!
    # https://support.twilio.com/hc/en-us/articles/223134027-Twilio-support-for-STOP-BLOCK-and-CANCEL-SMS-STOP-filtering-
    def calendar?
      message.downcase =~ /^calendar$/
    end

    def do_cancel
      inv = @person.invitations.upcoming(100).limit(9)
      if inv.zero?
        ::CustomSms.new(to: @person, msg: 'You have no upcoming sessions.').send
        session[:cancel] = false
      elsif inv.size == 1
        # this sends the notifications!
        inv.first.cancel!
        session[:cancel] = false # end cancellation session
      elsif session[:cancel] # cancel session already started
        res = get_numbers_or_all
        case res
        when :all
          inv.each{ |i| i.cancel! }
          session[:cancel] = false
        when false
          ::CustomSms.new(to: @person, msg: 'Please enter either a number or "all" to cancel.').send
        when present?
          res.each { |n| inv[n].cancel! }
          session[:cancel] = false
        end
      else # must send multi-invitation cancel message
        inv = person.invitations.upcoming(100).limit(9)
        ::MultiCancelSms.new(to: @person, invitations: inv).send
        session[:cancel] =  true
        Rails.logger.info('starting cancelling!')
      end
    end

    def do_confirm
      inv = @person.invitations.upcoming(100).limit(9)
      if inv.size.zero?
        ::CustomSms.new(to: @person, msg: 'You have no upcoming sessions.').send
        session[:confirm] = false
      elsif inv.size == 1
        # this sends the notifications!
        inv.first.confirm!
        session[:confirm] =  false # end confirm session
      elsif session[:confirm] # confirm session started
        res = get_numbers_or_all
        case res
        when :all
          inv.each{ |i| i.confirm! }
          session[:confirm] = false
        when false
          ::CustomSms.new(to: @person, msg: 'Please enter either a number or "all" to confirm.').send
        when present?
          res.each { |n| inv[n].confirm! }
          session[:confirm] = false
        end
      else # must send multi-invitation confirm message
        inv = person.invitations.upcoming(100).limit(9)
        ::MultiConfirmSms.new(to: @person, invitations: inv).send
        session[:confirm] =  true
        Rails.logger.info('starting confirming!')
      end
    end

    def do_remove
      # do the remove people thing.
      person.deactivate!('sms')
      person.save!
      # send the notifications to everyone.
      ::AdminMailer.deactivate(person: person).deliver_later
      ::RemoveSms.new(to: person).send
    end

    def remove?
      # using a fancy twilio add on.
      # 1 thousandth of a penny to not piss people off.
      # https://www.twilio.com/marketplace/add-ons/mobilecommons-optout
      if params['AddOns']
        add_ons = JSON.parse(params['AddOns'])
        mobile_commons = add_ons['results']['mobilecommons_optout'] || nil
        if mobile_commons
          return true if mobile_commons['result']['probability'] >= 0.85
        end
      end
      false
    end

    def sms_params
      params.permit(:From, :Body)
    end

    def twilio_params
      res = {}
      params.permit(:From, :To, :Body, :MessageSid, :DateCreated, :DateUpdated, :DateSent, :AccountSid, :WufooFormid, :SmsStatus, :FromZip, :FromCity,
        :FromState, :ErrorCode, :ErrorMessage, :Direction, :AccountSid).to_unsafe_hash.keys do |k, v|
        # behold the horror of translating twilio params to rails attributes
        res[k.gsub!(/(.)([A-Z])/, '\1_\2').downcase] = v
      end
      res
    end

    def save_twilio_message
      TwilioMessage.create(twilio_params)
    end
end
# rubocop:enable ClassLength
