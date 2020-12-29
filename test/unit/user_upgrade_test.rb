require 'test_helper'

class UserUpgradeTest < ActiveSupport::TestCase
  context "UserUpgrade:" do
    context "the #process_upgrade! method" do
      context "for a self upgrade" do
        context "to Gold" do
          setup do
            @user_upgrade = create(:self_gold_upgrade)
          end

          should "update the user's level if the payment status is paid" do
            @user_upgrade.process_upgrade!("paid")

            assert_equal(User::Levels::GOLD, @user_upgrade.recipient.level)
            assert_equal("complete", @user_upgrade.status)
          end

          should "not update the user's level if the payment is unpaid" do
            @user_upgrade.process_upgrade!("unpaid")

            assert_equal(User::Levels::MEMBER, @user_upgrade.recipient.level)
            assert_equal("processing", @user_upgrade.status)
          end

          should "not update the user's level if the upgrade status is complete" do
            @user_upgrade.update!(status: "complete")
            @user_upgrade.process_upgrade!("paid")

            assert_equal(User::Levels::MEMBER, @user_upgrade.recipient.level)
            assert_equal("complete", @user_upgrade.status)
          end

          should "log an account upgrade modaction" do
            assert_difference("ModAction.user_account_upgrade.count") do
              @user_upgrade.process_upgrade!("paid")
            end
          end

          should "send the recipient a dmail" do
            assert_difference("@user_upgrade.recipient.dmails.received.count") do
              @user_upgrade.process_upgrade!("paid")
            end
          end
        end
      end
    end

    context "the #create_checkout! method" do
      context "for a gifted upgrade" do
        context "to Gold" do
          should "prefill the Stripe checkout page with the purchaser's email address" do
            @user = create(:user, email_address: build(:email_address))
            @user_upgrade = create(:gift_gold_upgrade, purchaser: @user)
            @checkout = @user_upgrade.create_checkout!

            assert_equal(@user.email_address.address, @checkout.customer_email)
          end
        end
      end
    end

    context "the #receipt_url method" do
      mock_stripe!

      context "a pending upgrade" do
        should "not have a receipt" do
          @user_upgrade = create(:self_gold_upgrade, status: "pending")
          @user_upgrade.create_checkout!

          assert_equal(nil, @user_upgrade.receipt_url)
        end
      end

      context "a complete upgrade" do
        # XXX not supported yet by stripe-ruby-mock
        should_eventually "have a receipt" do
          @user_upgrade = create(:self_gold_upgrade, status: "complete")
          @user_upgrade.create_checkout!

          assert_equal("xxx", @user_upgrade.receipt_url)
        end
      end
    end

    context "the #refund! method" do
      should_eventually "refund a Gold upgrade" do
        @user_upgrade = create(:self_gold_upgrade, recipient: create(:gold_user), status: "complete")
        @user_upgrade.create_checkout!
        @user_upgrade.refund!

        assert_equal("refunded", @user_upgrade.reload.status)
        assert_equal(User::Levels::MEMBER, @user_upgrade.recipient.level)
      end
    end
  end
end
