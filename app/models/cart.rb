# frozen_string_literal: true

# == Schema Information
#
# Table name: carts
#
#  id           :integer          not null, primary key
#  name         :string(255)      default("default")
#  user_id      :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  description  :text(65535)
#  people_count :integer          default(0)
#

# should be renamed to pool...
class Cart < ApplicationRecord
  belongs_to :user

  has_many :carts_people, dependent: :destroy
  has_many :carts_users, dependent: :destroy

  has_many :users, through: :carts_users
  has_many :people, through: :carts_people
  delegate :size, to: :people

  has_many :comments, as: :commentable, dependent: :destroy

  before_create :set_owner_as_user
  validates :name, length: { in: 3..30 }
  validates :name, uniqueness: { message: 'Pool must have a unique name' }

  if ENV['RAPIDPRO_TOKEN']
    after_save :update_rapidpro, if: :saved_change_to_rapidpro_sync?
  end

  # keep current cart in carts_users,
  # add validation that it must be unique on scope of user.
  def owner
    user
  end

  def name_and_count
    "#{name}: #{people.size}"
  end

  def current_cart_for?
    carts_users.includes(:user).select(&:current_cart)&.map(&:user)
  end

  def assign_current_cart(user_id)
    cu = carts_users.find_or_create_by(user_id: user_id)
    cu.set_current_cart
    cu.save
  end

  def add_user_to_cart(user_id)
    users << User.find(user_id)
  end

  def remove_person_id(person_id)
    cart_person = carts_people.find_by(person_id: person_id)
    cart_person.destroy if cart_person.present?
  end

  def people_ids
    people.pluck(:id)
  end

  private

    def update_rapidpro
      if rapidpro_sync == true
        RapidproGroupJob.perform_async(id, 'create')
      else # creating
        RapidproGroupJob.perform_async(id, 'delete')
      end
    end

    def set_owner_as_user
      users << user
    end

end
