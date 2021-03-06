# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ApplicationController do
  class ApplicationTestController < ApplicationController
    def test_render
      head :ok
    end

    def test_redirect_back_or
      redirect_back_or '/fallback', notice: params[:notice]
    end
  end

  tests ApplicationTestController
  use_test_routes ApplicationTestController

  describe "#redirect_back_or" do
    as_a_viewer do
      it "redirects to fallback" do
        get :test_redirect_back_or, params: {test_route: true}
        assert_redirected_to '/fallback'
      end

      it "redirects to redirect_to" do
        get :test_redirect_back_or, params: {test_route: true, redirect_to: '/param'}
        assert_redirected_to '/param'
      end

      it "redirects to redirect_to with query" do
        get :test_redirect_back_or, params: {test_route: true, redirect_to: '/param?x=1&y=2'}
        assert_redirected_to '/param?x=1&y=2'
      end

      it "ignores blank redirect_to which comes from forms blindly filling it" do
        get :test_redirect_back_or, params: {test_route: true, redirect_to: ''}
        assert_redirected_to '/fallback'
      end

      describe "with referer" do
        before { request.env['HTTP_REFERER'] = '/header' }

        it "redirects to referrer" do
          get :test_redirect_back_or, params: {test_route: true}
          assert_redirected_to '/header'
        end

        it "prefers params over headers" do
          get :test_redirect_back_or, params: {test_route: true, redirect_to: '/param'}
          assert_redirected_to '/param'
        end
      end

      it "does not redirect to hacky url in redirect_to which might have come in via referrer" do
        Rails.logger.expects(:error)
        get :test_redirect_back_or, params: {test_route: true, redirect_to: 'http://hacks.com'}
        assert_redirected_to '/fallback'
      end

      it "does not redirect to hacky hash in redirect_to" do
        Rails.logger.expects(:error)
        get :test_redirect_back_or, params: {test_route: true, redirect_to: {host: 'hacks.com', path: 'bar'}}
        assert_redirected_to '/fallback'
      end

      it "can set a notice" do
        get :test_redirect_back_or, params: {test_route: true, redirect_to: '/param', notice: "hello"}
        assert_redirected_to '/param'
        assert flash[:notice]
      end
    end
  end
end
