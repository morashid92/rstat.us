require 'require_relative' if RUBY_VERSION[0,3] == '1.8'
require_relative 'acceptance_helper'

describe "following" do
  include AcceptanceHelper

  describe "yourself" do
    it "doesn't make you follow yourself after signing up" do
      u = Factory(:user)
      refute u.following? u.feed.url
    end

    it "disallows following yourself" do
      u = Factory(:user)
      u.follow! u.feed.url
      refute u.following? u.feed.url
    end
  end

  describe "other sites" do
    before do
      @u = Factory(:user)
      @a = Factory(:authorization, :user => @u)
      log_in(@u, @a.uid)
      visit "/"
      click_link "Follow Remote User"

      VCR.use_cassette('subscribe_remote') do
        fill_in 'url', :with => "steveklabnik@identi.ca"
        click_button "Follow"
      end
    end

    it "follows users on other sites" do
      assert_match "Now following steveklabnik.", page.body
      assert "/", current_path
    end

    it "has users on other sites on /following" do
      visit "/users/#{@u.username}/following"

      assert_match "steveklabnik", page.body
    end

    it "unfollows users from other sites" do
      visit "/users/#{@u.username}/following"

      VCR.use_cassette('unsubscribe_remote') do
        click_button "Unfollow"
      end

      assert_match "No longer following steveklabnik", page.body
    end

    it "only creates one Feed per remote_url" do
      u2 = Factory(:user)
      a2 = Factory(:authorization, :user => u2)
      log_in(u2, a2.uid)
      visit "/"
      click_link "Follow Remote User"

      assert_match "ostatus Sites", page.body

      VCR.use_cassette('subscribe_remote') do
        fill_in 'url', :with => "steveklabnik@identi.ca"
        click_button "Follow"
      end

      visit "/users/#{u2.username}/following"

      assert_match "Unfollow", page.body
    end
  end

  describe "on rstat.us" do
    it "follows another user" do
      u = Factory(:user)
      a = Factory(:authorization, :user => u)

      u2 = Factory(:user)

      log_in(u, a.uid)

      visit "/users/#{u2.username}"

      click_button "follow-#{u2.feed.id}"
      assert_match "Now following #{u2.username}", page.body
    end

    it "unfollows another user" do
      u = Factory(:user)
      a = Factory(:authorization, :user => u)

      u2 = Factory(:user)
      a2 = Factory(:authorization, :user => u2)

      log_in(u, a.uid)
      u.follow! u2.feed.url

      visit "/users/#{u.username}/following"
      click_button "unfollow-#{u2.feed.id}"

      assert_match "No longer following #{u2.username}", page.body
    end
  end

  describe "/following" do
    it "maintains the order in which you follow people" do
      aardvark = Factory(:user, :username => "aardvark", :created_at => Date.new(2010, 10, 23))
      zebra    = Factory(:user, :username => "zebra", :created_at => Date.new(2011, 10, 23))
      leopard  = Factory(:user, :username => "leopard", :created_at => Date.new(2011, 10, 23))
      a = Factory(:authorization, :user => aardvark)

      log_in(aardvark, a.uid)

      visit "/users/#{zebra.username}"
      click_button "follow-#{zebra.feed.id}"

      visit "/users/#{leopard.username}"
      click_button "follow-#{leopard.feed.id}"

      visit "/users/#{aardvark.username}/following"
      assert_match /leopard.*zebra/m, page.body
    end

    it "outputs json" do
      u = Factory(:user)
      a = Factory(:authorization, :user => u)

      log_in(u, a.uid)

      u2 = Factory(:user, :username => "user1")
      u.follow! u2.feed.url

      visit "/users/#{u.username}/following.json"

      json = JSON.parse(page.body)
      assert_equal "user1", json.last["username"]
    end

    it "properly displays title on your following page when logged in" do
      u = Factory(:user, :username => "dfnkt")
      a = Factory(:authorization, :user => u)

      log_in(u, a.uid)

      visit "/users/#{u.username}/following"
      assert_match /You're following/, page.body

    end

    it "uses your username if not logged in" do
      u = Factory(:user, :username => "dfnkt")

      visit "/users/#{u.username}/following"
      assert_match "#{u.username} is following", page.body
    end

    it "has a nice message if not following anyone" do
      u = Factory(:user, :username => "dfnkt")

      visit "/users/#{u.username}/following"

      assert_match "No one yet", page.body
    end

    describe "pagination" do
      before do
        @u = Factory(:user)
        a = Factory(:authorization, :user => @u)

        log_in(@u, a.uid)

        5.times do
          u2 = Factory(:user)
          @u.follow! u2.feed.url
        end
      end

      it "does not paginate when there are too few" do
        visit "/users/#{@u.username}/following"

        refute_match "Previous", page.body
        refute_match "Next", page.body
      end

      it "paginates forward only if on the first page" do
        visit "/users/#{@u.username}/following?per_page=3"

        refute_match "Previous", page.body
        assert_match "Next", page.body
      end

      it "paginates backward only if on the last page" do
        visit "/users/#{@u.username}/following?per_page=3"
        click_link "next_button"

        assert_match "Previous", page.body
        refute_match "Next", page.body
      end

      it "paginates forward and backward if on a middle page" do
        visit "/users/#{@u.username}/following?per_page=2"

        click_link "next_button"

        assert_match "Previous", page.body
        assert_match "Next", page.body
      end
    end
  end

  describe "/followers" do
    it "maintains the order in which people follow you" do
      aardvark = Factory(:user, :username => "aardvark", :created_at => Date.new(2010, 10, 23))
      zebra    = Factory(:user, :username => "zebra", :created_at => Date.new(2011, 10, 23))
      leopard  = Factory(:user, :username => "leopard", :created_at => Date.new(2011, 10, 23))

      aardvark_auth = Factory(:authorization, :user => aardvark)
      zebra_auth = Factory(:authorization, :user => zebra)
      leopard_auth = Factory(:authorization, :user => leopard)

      log_in(zebra, zebra_auth.uid)

      visit "/users/#{aardvark.username}"
      click_button "follow-#{aardvark.feed.id}"

      log_in(leopard, leopard_auth.uid)

      visit "/users/#{aardvark.username}"
      click_button "follow-#{aardvark.feed.id}"

      log_in(aardvark, aardvark_auth.uid)
      visit "/users/#{aardvark.username}/followers"
      assert_match /leopard.*zebra/m, page.body
    end

    it "properly displays title on your followers page when logged in" do
      u = Factory(:user, :username => "dfnkt")
      a = Factory(:authorization, :user => u)

      log_in(u, a.uid)

      visit "/users/#{u.username}/followers"
      assert_match /Your followers/, page.body

    end

    it "uses your username if not logged in" do
      u = Factory(:user, :username => "dfnkt")

      visit "/users/#{u.username}/followers"
      assert_match "#{u.username}'s followers", page.body
    end

    it "has a nice message if not followed by anyone" do
      u = Factory(:user, :username => "dfnkt")

      visit "/users/#{u.username}/followers"

      assert_match "No one yet", page.body
    end

    describe "pagination" do
      before do
        @u = Factory(:user)
        a = Factory(:authorization, :user => @u)

        log_in(@u, a.uid)

        5.times do
          u2 = Factory(:user)
          u2.follow! @u.feed.url
        end
      end

      it "does not paginate when there are too few" do
        visit "/users/#{@u.username}/followers"

        refute_match "Previous", page.body
        refute_match "Next", page.body
      end

      it "paginates forward only if on the first page" do
        visit "/users/#{@u.username}/followers?per_page=3"

        refute_match "Previous", page.body
        assert_match "Next", page.body
      end

      it "paginates backward only if on the last page" do
        visit "/users/#{@u.username}/followers?per_page=3"
        click_link "next_button"

        assert_match "Previous", page.body
        refute_match "Next", page.body
      end

      it "paginates forward and backward if on a middle page" do
        visit "/users/#{@u.username}/followers?per_page=2"

        click_link "next_button"

        assert_match "Previous", page.body
        assert_match "Next", page.body
      end
    end
  end
end
