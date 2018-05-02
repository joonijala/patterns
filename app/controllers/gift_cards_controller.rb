# frozen_string_literal: true

class GiftCardsController < ApplicationController
  before_action :set_gift_card, only: %i[show edit update destroy]
  skip_before_action :authenticate_user!, only: %i[activate card_check]
  helper_method :sort_column, :sort_direction

  GIFTABLE_TYPES = {
    'Person'     => Person,
    'Invitation' => Invitation
  }.freeze

  # GET /gift_cards
  # GET /gift_cards.csv
  def index
    if current_user.admin?
      @q_giftcards = GiftCard.ransack(params[:q])
    else
      @q_giftcards = GiftCard.where(created_by: current_user.id).ransack(params[:q])
    end
    @q_giftcards.sorts = [sort_column + ' ' + sort_direction] if @q_giftcards.sorts.empty?
    respond_to do |format|
      format.html do
        @gift_cards = @q_giftcards.result.includes(:person, :giftable).order(id: :desc).page(params[:page])
        # @recent_signups = Person.no_signup_card.paginate(page: params[:page]).where('signup_at > :startdate', { startdate: 3.months.ago }).order('signup_at DESC')
      end
      format.csv do
        @gift_cards = @q_giftcards.result.includes(:person, :giftable)
        send_data @gift_cards.export_csv,  filename: "GiftCards-#{Time.zone.today}.csv"
      end
    end
  end

  # GET /recent_signups
  # GET /recent_signups.csv
  def recent_signups
    @q_recent_signups = Person.no_signup_card.ransack(params[:q_signups], search_key: :q_signups)

    unless params[:q_signups]
      @q_recent_signups.created_at_date_gteq = 3.weeks.ago.strftime('%Y-%m-%d')
    end

    @recent_signups = @q_recent_signups.result.order(id: :desc).page(params[:page_signups])

    @new_gift_cards = []
    @recent_signups.length.times do
      @new_gift_cards << GiftCard.new
    end
  end

  # GET /gift_cards/1
  # GET /gift_cards/1.json
  def show; end

  # GET /gift_cards/new
  def new
    @last_gift_card = GiftCard.last # default scope is id: :desc
    @gift_card = GiftCard.new
  end

  # GET /gift_cards/1/edit
  def edit; end

  # POST /gift_cards
  # POST /gift_cards.json
  def create
    @gift_card = GiftCard.new(gift_card_params)
    @create_result = @gift_card.with_user(current_user).save
    respond_to do |format|
      if @create_result
        @total = @gift_card.person.blank? ? @gift_card.amount : @gift_card.person.gift_card_total
        @gift_card.finance_code = current_user&.team&.finance_code
        @gift_card.team = current_user&.team
        @gift_card.save
        format.js {}
        format.json {}
        format.html { redirect_to @gift_card, notice: 'Gift Card was successfully created.'  }
      else
        format.js {}
        format.html { render action: 'edit' }
        format.json { render json: @gift_card.errors, status: :unprocessable_entity }
      end
    end
  end

  # takes an card_activation_id, person_id, and sessionid
  def assign
    @card_activation = CardActivation.find(params[:card_activation_id])
    ca = @card_activation # for shortness.
    @gift_card = GiftCard.new(proxy_id: ca.sequence_id,
                              batch_id: ca.batch_id,
                              gift_card_number: ca.full_card_number.last(4),
                              person_id: params[:person_id],
                              giftable_type: params[:giftable_type],
                              giftable_id: params[:giftable_id],
                              finance_code: current_user&.team&.finance_code,
                              team: current_user&.team,
                              created_by: current_user.id)

    @total = @gift_card.person.gift_card_total
    @create_result = @gift_cart.save

    respond_to do |format|
      if @create_result
        format.js { render action: :create }
        format.json {}
        format.html { redirect_to @gift_card, notice: 'Gift Card was successfully created.'  }
      else
        format.js {}
        format.html { render action: 'edit' }
        format.json { render json: @gift_card.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /gift_cards/1
  # PATCH/PUT /gift_cards/1.json
  def update
    respond_to do |format|
      if @gift_card.update(gift_card_params)
        format.html { redirect_to @gift_card, notice: 'Gift card was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @gift_card.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /gift_cards/1
  # DELETE /gift_cards/1.json
  def destroy
    giftable = @gift_card.giftable
    @gift_card.destroy
    giftable&.reload # weirdo.
    respond_to do |format|
      format.html { redirect_back(fallback_location: gift_cards_path) }
      format.json { head :no_content }
      format.js {}
    end
  end

  def modal
    klass = GIFTABLE_TYPES.fetch(params[:giftable_type])
    @giftable = klass.find(params[:giftable_id])
    @gift_card = GiftCard.new
    @last_gift_card = GiftCard.last # default scope is id: :desc
    respond_to do |format|
      format.html
      format.js
    end
  end

  # def activate
  #   @card_number = params[:number]&.gsub(/[^0-9]/, '')
  #   @valid =  CreditCardValidations::Luhn.valid?(@card_number)
  #   @secure_code = params[:code]&.gsub(/[^0-9]/, '')
  #   respond_to do |format|
  #     format.xml
  #   end
  # end

  # # def activate_response # this is where the gather endpoint it.
  # #   # sets card to active
  # # end

  # def card_check
  #   @card_number = params[:number]&.gsub(/[^0-9]/, '')
  #   @valid =  CreditCardValidations::Luhn.valid?(@card_number)
  #   @secure_code = params[:code]&.gsub(/[^0-9]/, '') # three digits
  #   @expiration = params[:expiration]&.gsub(/[^0-9]/, '') # four digits
  #   respond_to do |format|
  #     format.xml
  #   end
  # end

  # def check_response # this is the gather endpoint for checking cards
  #   # returns true, and sets current value for card
  # end

  def sort_column
    GiftCard.column_names.include?(params[:sort]) ? params[:sort] : 'people.id'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : 'desc'
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_gift_card
      @gift_card = GiftCard.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def gift_card_params
      params.require(:gift_card).permit(:gift_card_number, :batch_id, :expiration_date, :person_id, :notes, :proxy_id, :created_by, :reason, :amount, :giftable_id, :giftable_type, :team_id, :finance_code)
    end
end
