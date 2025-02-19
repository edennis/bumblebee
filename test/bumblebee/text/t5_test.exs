defmodule Bumblebee.Text.T5Test do
  use ExUnit.Case, async: false

  import Bumblebee.TestHelpers

  @moduletag model_test_tags()

  describe "integration" do
    test "base model" do
      assert {:ok, %{model: model, params: params, spec: spec}} =
               Bumblebee.load_model({:hf, "t5-small"}, architecture: :base)

      assert %Bumblebee.Text.T5{architecture: :base} = spec

      inputs = %{
        "input_ids" =>
          Nx.tensor([[6536, 43, 118, 2008, 24, 293, 53, 3, 9, 1782, 19, 207, 21, 25, 1]]),
        "decoder_input_ids" => Nx.tensor([[0, 6536, 504, 24]])
      }

      outputs = Axon.predict(model, params, inputs)

      assert Nx.shape(outputs.hidden_state) == {1, 4, 512}

      assert_all_close(
        outputs.hidden_state[[0..-1//1, 1..3, 1..3]],
        Nx.tensor([
          [[0.1380, -0.0321, 0.0281], [0.0637, 0.0025, 0.0985], [-0.0019, 0.1075, 0.1575]]
        ]),
        atol: 1.0e-4
      )
    end

    test "base model (gated activation)" do
      assert {:ok, %{model: model, params: params, spec: spec}} =
               Bumblebee.load_model({:hf, "google/flan-t5-small"}, architecture: :base)

      assert %Bumblebee.Text.T5{architecture: :base} = spec

      inputs = %{
        "input_ids" =>
          Nx.tensor([[6536, 43, 118, 2008, 24, 293, 53, 3, 9, 1782, 19, 207, 21, 25, 1]]),
        "decoder_input_ids" => Nx.tensor([[0, 6536, 504, 24]])
      }

      outputs = Axon.predict(model, params, inputs)

      assert Nx.shape(outputs.hidden_state) == {1, 4, 512}

      assert_all_close(
        outputs.hidden_state[[0..-1//1, 1..3, 1..3]],
        Nx.tensor([
          [[-0.1101, 0.0512, 0.1005], [0.0091, -0.0398, 0.0895], [-0.1061, -0.0152, 0.0702]]
        ]),
        atol: 1.0e-4
      )
    end

    test "conditional generation model" do
      assert {:ok, %{model: model, params: params, spec: spec}} =
               Bumblebee.load_model({:hf, "t5-small"},
                 architecture: :for_conditional_generation
               )

      assert %Bumblebee.Text.T5{architecture: :for_conditional_generation} = spec

      input_ids = Nx.tensor([[37, 32099, 10681, 16, 32098, 2447, 1]])
      decoder_input_ids = Nx.tensor([[32099, 5295, 1782, 32098, 8, 32097, 1]])

      inputs = %{
        "input_ids" => input_ids,
        "decoder_input_ids" => decoder_input_ids
      }

      outputs = Axon.predict(model, params, inputs)

      assert Nx.shape(outputs.logits) == {1, 7, 32128}

      assert_all_close(
        outputs.logits[[0, 1..3, 1..3]],
        Nx.tensor([
          [
            [-11.7720, -12.8368, -9.6471],
            [-10.6815, -11.4800, -8.5046],
            [-15.8921, -15.2948, -8.4964]
          ]
        ]),
        atol: 1.0e-4
      )
    end

    test "conditional generation model (tied embeddings)" do
      assert {:ok, %{model: model, params: params, spec: spec}} =
               Bumblebee.load_model({:hf, "google/flan-t5-small"})

      assert %Bumblebee.Text.T5{architecture: :for_conditional_generation} = spec

      input_ids = Nx.tensor([[37, 32099, 10681, 16, 32098, 2447, 1]])
      decoder_input_ids = Nx.tensor([[32099, 5295, 1782, 32098, 8, 32097, 1]])

      inputs = %{
        "input_ids" => input_ids,
        "decoder_input_ids" => decoder_input_ids
      }

      outputs = Axon.predict(model, params, inputs)

      assert Nx.shape(outputs.logits) == {1, 7, 32128}

      assert_all_close(
        outputs.logits[[0, 1..3, 1..3]],
        Nx.tensor([
          [2.7100, -3.0434, 1.2578],
          [3.1423, -3.6663, 1.2443],
          [1.0911, -3.8732, 0.5008]
        ]),
        atol: 1.0e-4
      )
    end

    test "text generation" do
      assert {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "t5-small"})
      assert {:ok, model_info} = Bumblebee.load_model({:hf, "t5-small"})

      text = "translate English to German: How old are you?"

      inputs = Bumblebee.apply_tokenizer(tokenizer, text)

      generate =
        Bumblebee.Text.Generation.build_generate(model_info.model, model_info.spec,
          min_length: 0,
          max_length: 10
        )

      token_ids = EXLA.jit(generate).(model_info.params, inputs)

      assert Bumblebee.Tokenizer.decode(tokenizer, token_ids) == ["Wie alt sind Sie?"]
    end

    test "text generation (tied embeddings)" do
      assert {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "google/flan-t5-small"})
      assert {:ok, model_info} = Bumblebee.load_model({:hf, "google/flan-t5-small"})

      text = "translate English to German: How old are you?"

      inputs = Bumblebee.apply_tokenizer(tokenizer, text)

      generate =
        Bumblebee.Text.Generation.build_generate(model_info.model, model_info.spec,
          min_length: 0,
          max_length: 10
        )

      token_ids = EXLA.jit(generate).(model_info.params, inputs)

      assert Bumblebee.Tokenizer.decode(tokenizer, token_ids) == ["Wie ich er bitten?"]
    end
  end
end
