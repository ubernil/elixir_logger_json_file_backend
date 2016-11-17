defmodule LoggerJSONFileBackendTest do
  use ExUnit.Case, async: false
  require Logger

  @backend {LoggerJSONFileBackend, :test}
  Logger.add_backend @backend

  setup do
    config [path: "test/logs/test.log", level: :info, metadata: [:foo], metadata_triming: true, json_encoder: Poison]
    on_exit fn ->
      path && File.rm_rf!(Path.dirname(path))
    end
  end

  test "create log file" do
    refute File.exists?(path)
    Logger.info("msg body", [foo: "bar", baz: []])
    assert File.exists?(path)
    json_log = Poison.decode! log
    assert json_log["level"] == "info"
    assert json_log["message"] == "msg body"
    assert Regex.match?(~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}/, json_log["time"])
    assert json_log["foo"] == "bar"
    assert is_nil(json_log["baz"])
  end

  test "can log structured object" do
    Logger.info("msg body", [foo: %{bar: [:baz]}])
    json_log = Poison.decode! log
    refute is_nil(json_log["foo"])
    assert json_log["foo"]["bar"] == ["baz"]
  end

  test "use another encoder" do
    config [path: "test/logs/test.log", level: :info, json_encoder: JSON, metadata: [:foo]]
    Logger.info("msg body", [foo: "bar", baz: []])
    json_log = JSON.decode! log
    assert json_log["level"] == "info"
    assert json_log["message"] == "msg body"
    assert Regex.match?(~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}/, json_log["time"])
    assert json_log["foo"] == "bar"
    assert is_nil(json_log["baz"])
  end

  test "does'nt trim metadata" do
    config [path: "test/logs/test.log", level: :info, json_encoder: JSON, metadata_triming: false, metadata: [:foo]]
    Logger.info("msg body", [foo: "bar", baz: %{hoge: 1, fuga: 2}])
    json_log = JSON.decode! log
    assert json_log["level"] == "info"
    assert json_log["message"] == "msg body"
    assert Regex.match?(~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}/, json_log["time"])
    assert json_log["foo"] == "bar"
    assert json_log["baz"] == %{"hoge" => 1, "fuga" => 2}
  end

  test "message should be string" do
    Logger.info(["msg", 32, "body"])
    json_log = Poison.decode! log
    assert json_log["message"] == "msg body"
  end

  defp path do
    {:ok, path} = GenEvent.call(Logger, @backend, :path)
    path
  end

  defp log do
    File.read!(path)
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end
end
