# encoding: utf-8

require 'spec_helper'

shared_examples_for 'a wrappable endpoint' do |body, method, endpoint|
  context 'with no envelope' do
    before do
      API.envelope = nil
    end

    it 'returns just the body' do
      send(method, endpoint)
      expect(response.body).to eq body
    end
  end

  context 'with an envelope' do
    before do
      API.envelope = 'data'
    end

    after do
      API.envelope = nil
    end

    it 'returns the body, wrapped in an envelope' do
      send(method, endpoint)
      expect(response.body).to eq("{\"data\":#{body}}")
    end
  end
end

describe Api::V1::TestersController, type: :controller do
  before { API.pretty_print = false }

  describe 'GET #as_one' do
    before { @tester = FactoryGirl.create(:tester, name: 'Tester', last_name: 'Atqu') }

    it 'returns one' do
      get :as_one, format: :json
      expect(response.body).to eq({ id: 1, name: 'Tester', product: [] }.to_json)
    end

    it_behaves_like 'a wrappable endpoint', { id: 1, name: 'Tester', product: [] }.to_json, 'get', 'as_one'
  end

  describe 'GET #as_true' do
    it 'returns true' do
      get :as_true
      expect(response.body).to eq("true")
    end

    it_behaves_like 'a wrappable endpoint', 'true', 'get', 'as_true'
  end

  describe 'GET #as_false' do
    it 'returns false' do
      get :as_false
      expect(response.body).to eq("false")
    end

    it_behaves_like 'a wrappable endpoint', 'false', 'get', 'as_false'
  end

  describe 'GET #as_nil' do
    it 'returns a null object' do
      get :as_nil
      expect(response.body).to eq("null")
    end

    it_behaves_like 'a wrappable endpoint', 'null', 'get', 'as_nil'
  end

  describe 'GET #as_hash' do
    it 'returns a hash' do
      get :as_hash
      expect(response.body).to eq({
        one: 'two',
        three: 'four'
      }.to_json)
    end

    it_behaves_like 'a wrappable endpoint', {one: 'two', three: 'four'}.to_json, 'get', 'as_hash'
  end

  describe 'GET #as_arr' do
    it 'returns an array' do
      get :as_arr
      expect(response.body).to eq(%w(one two three).to_json)
    end

    it_behaves_like 'a wrappable endpoint', %w(one two three).to_json, 'get', 'as_arr'
  end

  describe 'GET #as_str' do
    it 'returns a string' do
      get :as_str, format: 'json'
      expect(response.body).to eq('one')
    end

    context 'with no envelope' do
      before do
        API.envelope = nil
      end

      it 'returns just the body' do
        get :as_str, format: 'json'
        expect(response.body).to eq 'one'
      end
    end

    context 'with an envelope' do
      before do
        API.envelope = 'data'
      end

      after do
        API.envelope = nil
      end

      it 'returns the body, wrapped in an envelope' do
        get :as_str, format: 'json'
        expect(response.body).to eq("{\"data\":\"one\"}")
      end
    end
  end

  describe 'GET #single_as_arr' do
    before { @tester = FactoryGirl.create(:tester, name: 'Tester', last_name: 'Atqu') }
    it 'returns an array with one element' do
      get :single_as_arr, format: 'json'
      expect(response.body).to eq([{ id: 1, name: 'Tester', product: [] }].to_json)
    end

    it_behaves_like 'a wrappable endpoint', [{ id: 1, name: 'Tester', product: [] }].to_json, 'get', 'single_as_arr'
  end

  describe 'GET #errors' do
    before do
      @one = FactoryGirl.create(:tester, name: 'John', last_name: 'Smith')
    end

    describe 'with a standard exception' do
      it 'returns the actual exception' do
        allow(controller)
          .to receive(:errors)
          .and_raise(StandardError.new('Exception'))

        get :errors
        expect(response.body).to eq({ errors: 'Something went wrong.' }.to_json)
      end
    end

    describe 'with an exception handler that raises the error' do
      it 'raises the error' do
        allow(controller)
          .to receive(:errors)
          .and_raise(StandardError.new('Blah'))

        allow(API).to receive(:exception_handler).and_return(->(e) { raise e })

        expect { get :errors }.to raise_error('Blah')
      end
    end

    describe 'with CanCan::AccessDenied' do
      it 'returns 401 unauthorized' do
        CanCan = Class.new(Exception)
        CanCan::AccessDenied = Class.new(Exception)
        allow(controller)
          .to receive(:errors)
          .and_raise(CanCan::AccessDenied.new('Unauthorized'))

        get :errors
        expect(response.body).to eq({ errors: 'You are not authorized to do that.' }.to_json)
        expect(response.status).to eq 401
      end
    end

    describe 'with an invalid record' do
      it 'returns 400 bad request' do
        get :invalid_request
        expect(response.body).to eq({
          errors: {
            name: ["Name can't be blank"]
          }
        }.to_json)
        expect(response.status).to eq 400
      end
    end

    describe 'with a not-found record' do
      it 'returns 404 not found' do
        allow(controller)
          .to receive(:errors)
          .and_raise(ActiveRecord::RecordNotFound.new('Not Found'))

        get :errors
        expect(response.body).to eq({
          errors: 'Not found.'
        }.to_json)
        expect(response.status).to eq 404
      end
    end

    describe 'with a not-unique record' do
      it 'returns 409 conflict' do
        allow(controller)
          .to receive(:errors)
          .and_raise(ActiveRecord::RecordNotUnique.new('Not Unique.', nil))

        get :errors
        expect(response.body).to eq({ errors: 'Record not unique.' }.to_json)
        expect(response.status).to eq 409
      end
    end
  end

  describe 'GET #with_status' do
    it 'returns data with a status' do
      get :with_status
      expect(response.body).to eq('status')
      expect(response.status).to eq 201
    end
  end

  describe 'GET #with_bad_verify_perms' do
    let!(:post) { FactoryGirl.create(:post) }
    before do
      allow_any_instance_of(API::Serializer)
        .to receive(:validates?)
        .and_call_original

      allow_any_instance_of(API::Serializer)
        .to receive(:validates?)
        .with('title')
        .and_return(false)
    end

    it 'returns everything but the title attribute' do
      get :with_bad_verify_perms
      expect(response.body).to eq({ id: post.id, blurb: post.blurb }.to_json)
    end
  end

  describe 'GET #with_cache_serialized' do
    before { @tester = FactoryGirl.create(:tester, name: 'Tester', last_name: 'Atqu') }
    it 'caches a response' do
      allow(Rails).to receive_message_chain(:cache, :fetch).and_return('testing cache')
      expect(Rails).to receive_message_chain(:cache, :fetch).with('banana-api-endpoint', {})

      get :with_cache_serialized
      expect(response.body).to eq('testing cache')
    end

    it 'returns a cached version if it already exists' do
      Rails.cache.write('banana-api-endpoint', 'different response')
      get :with_cache_serialized
      expect(response.body).to eq('different response')
    end

    it 'writes cache only once' do
      allow(controller).to receive(:append_meta).and_return('testing')
      expect(controller).to receive(:append_meta)
      get :with_cache_serialized
      expect(response.body).to eq('testing'.to_json)

      expect(controller).to_not receive(:append_meta)
      get :with_cache_serialized
      expect(response.body).to eq('testing'.to_json)
    end

    it 'correctly shows associations' do
      @product = FactoryGirl.create_list(:product, 2, created_at: Time.parse('Jan 1, 2015 00:00:00 UTC'), updated_at: Time.parse('Jan 1, 2015 00:00:00 UTC'))
      get :with_cache_serialized
      expect(response.body).to eq({
        id: 1,
        name: 'Tester',
        product: [
          {
            id: 1,
            name: 'blah',
            desc: 'so on',
            created_at: '2015-01-01T00:00:00.000000Z',
            updated_at: '2015-01-01T00:00:00.000000Z'
          },
          {
            id: 2,
            name: 'blah',
            desc: 'so on',
            created_at: '2015-01-01T00:00:00.000000Z',
            updated_at: '2015-01-01T00:00:00.000000Z'
          }
        ]
      }.to_json)

      get :with_cache_serialized
      expect(response.body).to eq({
        id: 1,
        name: 'Tester',
        product: [
          {
            id: 1,
            name: 'blah',
            desc: 'so on',
            created_at: '2015-01-01T00:00:00.000000Z',
            updated_at: '2015-01-01T00:00:00.000000Z'
          },
          {
            id: 2,
            name: 'blah',
            desc: 'so on',
            created_at: '2015-01-01T00:00:00.000000Z',
            updated_at: '2015-01-01T00:00:00.000000Z'
          }
        ]
      }.to_json)
    end
  end

  describe 'GET #with_elements' do
    context 'with an envelope' do
      before do
        API.envelope = 'data'
      end

      after do
        API.envelope = nil
      end

      it 'returns data with top level elements' do
        get :with_hash_elements
        expect(response.body).to eq({
          data: {
            name: 'elements'
          },
          banana: 'cream pie'
        }.to_json)
      end
    end
    context 'with no envelope' do
      context 'with a hash' do
        it 'returns data with top level elements' do
          get :with_hash_elements
          expect(response.body).to eq({
            name: 'elements',
            banana: 'cream pie'
          }.to_json)
        end
      end

      context 'with a boolean' do
        it 'returns no top level elements' do
          get :with_bool_elements
          expect(response.body).to eq("true")
        end
      end

      context 'with a string' do
        it 'returns no top level elements' do
          get :with_string_elements
          expect(response.body).to eq("elements")
        end
      end

      context 'with an array' do
        it 'returns no top level elements' do
          get :with_arr_elements
          expect(response.body).to eq(['one', 'two', 'three'].to_json)
        end
      end
    end
  end

  describe 'GET #with_callback' do
    context 'if jsonp is enabled' do
      before { API.jsonp = true }
      context 'with an envelope' do
        before do
          API.envelope = 'data'
        end

        after do
          API.envelope = nil
        end

        it 'returns data wrapped in a jsonp callback' do
          get :with_callback
          expect(response.body).to eq('/**/test({"data":"hello","meta":{"status":200}})')
        end

        context 'with a custom param callback' do
          it 'wraps the response with that callback instead' do
            get :with_callback, callback: 'another'
            expect(response.body).to eq('/**/another({"data":"hello","meta":{"status":200}})')
          end
        end
      end
      context 'with no envelope' do
        before { API.envelope = nil }
        it 'returns a jsonp string' do
          get :with_callback
          expect(response.body).to eq('/**/test({"data":"hello","meta":{"status":200}})')
        end

        context 'with a custom param callback' do
          it 'wraps the response with that callback instead' do
            get :with_callback, callback: 'another'
            expect(response.body).to eq('/**/another({"data":"hello","meta":{"status":200}})')
          end
        end
      end
    end
    context 'if jsonp is disabled' do
      before { API.jsonp = false }
      it 'returns just a body' do
        get :with_callback
        expect(response.body).to eq 'hello'
      end
    end
  end

  describe 'GET #index' do
    before do
      @one = FactoryGirl.create(:tester, name: 'Mike', last_name: 'Sea')
      @two = FactoryGirl.create(:tester, name: 'Tom', last_name: 'Hanks')
      @product = FactoryGirl.create(:product)
      get :index, format: 'json'
    end

    # product_serialized has no serializer, so should show up as raw fields.
    # It is also a default_association so should always show up.
    let(:product_serialized) do
      {
        product: [
          {
            id: @product.id,
            name: @product.name,
            desc: @product.desc,
            created_at: @product.created_at,
            updated_at: @product.updated_at
          }
        ]
      }
    end

    let(:post_serialized) do
      {
        post: {
          id: 1,
          title: 'Hi',
          blurb: "What's up?"
        }
      }
    end

    it 'responds success' do
      expect(response).to be_success
    end

    it 'responds with data' do
      expect(response.body).to eq([
        {
          id: 1,
          name: 'Mike'
        }.merge(product_serialized),
        {
          id: 2,
          name: 'Tom'
        }.merge(product_serialized)
      ].to_json)
    end

    it 'responds to field inclusion' do
      get :index, only: ['id'], format: 'json'
      expect(response.body).to eq([
        {
          id: 1
        }.merge(product_serialized),
        {
          id: 2
        }.merge(product_serialized)
      ].to_json)
    end

    it 'responds to field exclusion' do
      get :index, format: 'json', except: ['id']
      expect(response.body).to eq([
        {
          name: 'Mike'
        }.merge(product_serialized),
        {
          name: 'Tom'
        }.merge(product_serialized)
      ].to_json)
    end

    context 'optional fields' do
      it 'responds to optional fields' do
        get :index, format: 'json', extra_fields: ['last_name']
        expect(response.body).to eq([
          {
            id: 1,
            name: 'Mike',
            last_name: 'Sea'
          }.merge(product_serialized),
          {
            id: 2,
            name: 'Tom',
            last_name: 'Hanks'
          }.merge(product_serialized)
        ].to_json)
      end

      context 'if warn_invalid_fields is true' do
        context 'and there is an envelope' do
          before do
            API.envelope = 'data'
          end

          after do
            API.envelope = nil
          end

          it 'throws a warning for bad optional fields' do
            allow(API).to receive(:warn_invalid_fields).and_return(true)

            get :index, format: 'json', extra_fields: ['favorite_animal']
            expect(response.body).to eq({
             data: [
                {
                  id: 1,
                  name: 'Mike'
                }.merge(product_serialized),
                {
                  id: 2,
                  name: 'Tom'
                }.merge(product_serialized)
              ],
              warnings: [
                "The 'favorite_animal' field is not a valid optional field"
              ]
            }.to_json)
          end
        end

        context 'and there is no envelope' do
          before do
            API.envelope = nil
          end

          it 'does not show warnings' do
            allow(API).to receive(:warn_invalid_fields).and_return(true)

            get :index, format: 'json', extra_fields: ['favorite_animal']
            expect(response.body).to eq([
              {
                id: 1,
                name: 'Mike'
              }.merge(product_serialized),
              {
                id: 2,
                name: 'Tom'
              }.merge(product_serialized)
            ].to_json)
          end
        end
      end

      context 'if warn_invalid_fields is falsey' do
        context 'and there is an envelope' do
          before do
            API.envelope = 'data'
          end

          after do
            API.envelope = nil
          end

          it 'throws no warning for bad optional fields' do
            allow(API).to receive(:warn_invalid_fields).and_return(false)

            get :index, format: 'json', extra_fields: ['favorite_animal']
            expect(response.body).to eq({
              data: [
                {
                  id: 1,
                  name: 'Mike'
                }.merge(product_serialized),
                {
                  id: 2,
                  name: 'Tom'
                }.merge(product_serialized)
              ]
            }.to_json)
          end
        end

        context 'and there is no envelope' do
          before do
            API.envelope = nil
          end

          it 'throws no warning for bad optional fields' do
            allow(API).to receive(:warn_invalid_fields).and_return(false)

            get :index, format: 'json', extra_fields: ['favorite_animal']
            expect(response.body).to eq([
              {
                id: 1,
                name: 'Mike'
              }.merge(product_serialized),
              {
                id: 2,
                name: 'Tom'
              }.merge(product_serialized)
            ].to_json)
          end
        end
      end
    end

    context 'associations' do
      it 'responds to associations' do
        FactoryGirl.create(:post)
        get :index, format: 'json', associations: ['post']
        expect(response.body).to eq([
          {
            id: 1,
            name: 'Mike'
          }.merge(post_serialized).merge(product_serialized),
          {
            id: 2,
            name: 'Tom'
          }.merge(post_serialized).merge(product_serialized)
        ].to_json)
      end

      context 'if validate_associations is true' do
        context 'if you specify an invalid association' do
          it 'returns an error' do
            allow(API).to receive(:validate_associations).and_return(true)
            get :index, format: 'json', associations: ['octopus']
            expect(response.body).to eq({
              errors: "The 'octopus' association does not exist."
            }.to_json)
          end
        end
      end
      context 'if validate_associations is false' do
        context 'if you specify an invalid association' do
          it 'does not throw an error' do
            allow(API).to receive(:validate_associations).and_return(nil)
            get :index, format: 'json', associations: ['octopus']
            expect(response.body).to eq([
              {
                id: 1,
                name: 'Mike'
              }.merge(product_serialized),
              {
                id: 2,
                name: 'Tom'
              }.merge(product_serialized)
            ].to_json)
          end
        end
      end

      context 'sub fields' do
        it 'returns fields from an association' do
          FactoryGirl.create(:post)
          get :index, format: :json, associations: ['post'], post_fields: ['id']
          expect(response.body).to eq([
            {
              id: 1,
              name: 'Mike'
            }.merge(product_serialized).merge(
              post: {
                id: 1
              }
            ),
            {
              id: 2,
              name: 'Tom'
            }.merge(product_serialized).merge(
              post: {
                id: 1
              }
            )
          ].to_json)
        end
      end

      context 'sub optional fields' do
        it 'returns optional fields from an association' do
          FactoryGirl.create(:post)
          get :index, format: :json, associations: ['post'],
                      post_extra_fields: ['joke']
          expect(response.body).to eq([
            {
              id: 1,
              name: 'Mike'
            }.merge(product_serialized).merge(
              post: {
                id: 1,
                title: 'Hi',
                blurb: "What's up?",
                joke: 'Why was six afraid of seven?'
              }
            ),
            {
              id: 2,
              name: 'Tom'
            }.merge(product_serialized).merge(
              post: {
                id: 1,
                title: 'Hi',
                blurb: "What's up?",
                joke: 'Why was six afraid of seven?'
              }
            )
          ].to_json)
        end
      end

      context 'sub associations' do
        it 'returns associations from an association' do
          FactoryGirl.create(:post)
          get :index, format: :json, associations: ['post'],
                      post_associations: ['myself']
          expect(response.body).to eq([
            {
              id: 1,
              name: 'Mike'
            }.merge(product_serialized).merge(
              post: {
                id: 1,
                title: 'Hi',
                blurb: "What's up?",
                myself: {
                  id: 1,
                  title: 'Hi',
                  blurb: "What's up?"
                }
              }
            ),
            {
              id: 2,
              name: 'Tom'
            }.merge(product_serialized).merge(
              post: {
                id: 1,
                title: 'Hi',
                blurb: "What's up?",
                myself: {
                  id: 1,
                  title: 'Hi',
                  blurb: "What's up?"
                }
              }
            )
          ].to_json)
        end
      end
    end
  end
end
