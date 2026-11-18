# frozen_string_literal: true

require "spec_helper"

RSpec.describe Trysac::WebhookInbox::Store do
  def build_request(id:, inbox: "github", body: "{}")
    Trysac::WebhookInbox::CapturedRequest.new(
      id: id, inbox: inbox, method: "POST", path: "/hooks/#{inbox}", query: "",
      headers: [["content-type", "application/json"]], body: body, received_at: 1_700_000_000
    )
  end

  describe "ring-buffer eviction" do
    let(:store) do
      described_class.new(max_requests: 1_000).tap do |store|
        ids = Trysac::WebhookInbox::IdGenerator.sequential
        1_001.times { store.add(build_request(id: ids.call)) }
      end
    end

    it "evicts the oldest request on the 1_001st insertion when max_requests is 1_000" do
      expect(store.size).to eq(1_000)
      expect(store.find("msg_000001")).to be_nil
    end

    it "keeps the newer requests, newest first" do
      expect([store.find("msg_000002"), store.find("msg_001001")]).to all(be_a(Trysac::WebhookInbox::CapturedRequest))
      expect(store.by_inbox("github").first.id).to eq("msg_001001")
    end
  end

  it "rejects invalid max_requests" do
    expect { described_class.new(max_requests: 0) }.to raise_webhook_error(:invalid_inbox)
  end

  it "validates inbox names" do
    expect { described_class.validate_inbox!("Bad Name") }.to raise_webhook_error(:invalid_inbox)
    expect { described_class.validate_inbox!("a" * 65) }.to raise_webhook_error(:invalid_inbox)
  end

  describe "re-adding and deleting" do
    let(:store) do
      described_class.new(max_requests: 5).tap do |store|
        store.add(build_request(id: "msg_1", inbox: "a"))
        store.add(build_request(id: "msg_2", inbox: "b"))
        store.add(build_request(id: "msg_1", inbox: "a", body: "updated"))
      end
    end

    it "updates existing ID order if re-added" do
      expect([store.inboxes, store.all.map(&:id)]).to eq([%w[a b], %w[msg_1 msg_2]])
    end

    it "deletes by inbox" do
      expect(store.delete_inbox("a")).to eq(1)
      expect(store.by_inbox("a")).to be_empty
    end
  end

  it "generates random IDs with IdGenerator#call and #next_id" do
    gen = Trysac::WebhookInbox::IdGenerator.new
    ids = [gen.call, gen.next_id]
    expect(ids).to all(match(/\Amsg_[A-Za-z0-9]{24}\z/))
    expect(ids.uniq.length).to eq(2)
  end

  it "starts sequential IDs at the given number" do
    expect(Trysac::WebhookInbox::IdGenerator.sequential(10).next_id).to eq("msg_000010")
  end
end
