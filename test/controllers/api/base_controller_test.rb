# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::BaseController do
  class ApiBaseTestController < Api::BaseController
    def test_render
      head :ok
    end

    private

    # turned off in test ... but we want to simulate it
    def allow_forgery_protection
      true
    end
  end

  tests ApiBaseTestController
  use_test_routes ApiBaseTestController

  before { @controller.stubs(:store_requested_oauth_scope) }

  describe "#paginate" do
    it 'paginates array' do
      @controller.send(:paginate, Array.new(1000).fill('a')).size.must_equal 1000
    end

    it 'paginates scope' do
      Deploy.stubs(:page).with(1).returns('foo')
      @controller.send(:paginate, Deploy).must_equal 'foo'
    end
  end

  describe "#current_project" do
    it "returns cached @project" do
      @controller.send(:current_project).must_be_nil
      @controller.instance_variable_set(:@project, 1)
      @controller.send(:current_project).must_equal 1
    end
  end

  describe "#enforce_json_format" do
    it "fails without json" do
      get :test_render, params: {test_route: true}
      assert_response :unsupported_media_type
    end

    it "passes with json" do
      get :test_render, params: {test_route: true}, format: :json
      assert_response :unauthorized
    end

    it "does not pass with only json header" do
      json!
      get :test_render, params: {test_route: true}
      assert_response :unsupported_media_type
    end
  end

  describe "#store_requested_oauth_scope" do
    before { @controller.unstub(:store_requested_oauth_scope) }

    it "stores the controller scope" do
      I18n.expects(:t).with('doorkeeper.applications.help.scopes').returns('foo api_base_test')
      get :test_render, params: {test_route: true}
      request.env['requested_oauth_scope'].must_equal 'api_base_test'
    end

    it "fails when scope is unknown" do
      e = assert_raises(RuntimeError) { get :test_render, params: {test_route: true} }
      e.message.must_include "Add api_base_test to"
    end
  end
end

describe "Api::BaseController Integration" do
  describe "#using_per_request_auth?" do
    let(:user) { users(:super_admin) }
    let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, scopes: 'default') }
    let(:post_params) { {lock: {resource_id: nil, resource_type: nil}, format: :json} }

    with_forgery_protection

    it 'can POST without authenticiy_token when logging in via per request doorkeeper auth' do
      post '/api/locks', params: post_params, headers: {'Authorization' => "Bearer #{token.token}"}
      assert_response :success
    end

    it 'can POST without authenticiy_token when logging in via per request basic auth' do
      auth = "Basic #{Base64.encode64(user.email + ':' + user.token).strip}"
      post '/api/locks', params: post_params, headers: {'Authorization' => auth}
      assert_response :success
    end

    it 'does not authenticate twice' do
      ::Doorkeeper::OAuth::Token.expects(:authenticate).returns(token) # called inside of DoorkeeperStrategy
      post '/api/locks', params: post_params, headers: {'Authorization' => "Bearer #{token.token}"}
      assert_response :success
    end

    describe "when in the browser" do
      before { stub_session_auth }

      it 'can GET without authenticiy_token' do
        get '/api/locks', params: {format: :json}
        assert_response :success
      end

      it 'cannot POST without authenticiy_token' do
        assert_raises ActionController::InvalidAuthenticityToken do
          post '/api/locks', params: post_params
        end
      end
    end

    it 'cannot POST without authenticiy_token when not logged in' do
      assert_raises ActionController::InvalidAuthenticityToken do
        post '/api/locks', params: post_params
      end
    end
  end
end
