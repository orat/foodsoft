# encoding: utf-8
class VokomokumController < ApplicationController

  skip_before_filter :authenticate, :only => :login
  before_filter :authenticate_finance, :only => :export_amounts

  def login
    # use cookies, but allow to get them from parameters (if on other domain)
    sweets = params.slice(:Mem, :Key)
    sweets = cookies if sweets.empty?

    userinfo = FoodsoftVokomokum.check_user(sweets)
    userinfo.nil? and raise FoodsoftVokomokum::AuthnException.new('User not logged in')
    user = update_or_create_user(userinfo[:id],
                                 userinfo[:email],
                                 userinfo[:first_name],
                                 userinfo[:last_name])
    super user

    # XXX redirection code copied from SessionController#create
    if session[:return_to].present?
      redirect_to_url = session[:return_to]
      session[:return_to] = nil
    else
      redirect_to_url = root_url
    end
    redirect_to redirect_to_url

  rescue FoodsoftVokomokum::AuthnException => e
    Rails.logger.warn "Vokomokum authentication failed: #{e.message}"
    returl = Addressable::URI.parse(FoodsoftConfig[:vokomokum_members_url])
    returl.query_values = (returl.query_values or {}).merge({came_from: request.original_url})
    redirect_to returl.to_s
  end

  def export_amounts
    send_data FoodsoftVokomokum.export_amounts, filename: 'vers.csv', type: 'text/plain; charset=utf-8', disposition: 'inline'
  end


  protected

  def update_or_create_user(id, email, first_name, last_name, workgroups=[])
    User.transaction do
      begin
        user = User.find(id)
      rescue ActiveRecord::RecordNotFound
        user = User.new
        user.id = id
        # no password is used, enter complex random string
        user.password = user.new_random_password(8)
      end
      user.update_attributes email: email, first_name: first_name, last_name: last_name
      user.save!
      # make sure user has an ordergroup (different group id though, since we also have workgroups)
      unless user.ordergroup
        ordergroup = Ordergroup.create!(name: user.display.truncate(25))
        user.memberships.create!(group: ordergroup)
      end
      # TODO update associations to existing workgroups with matching name
      user
    end
  end

end
