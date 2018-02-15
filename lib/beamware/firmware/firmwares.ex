defmodule Beamware.Firmwares do
  import Ecto.Query

  alias Beamware.Accounts.TenantKey
  alias Beamware.Firmwares.Firmware
  alias Beamware.Repo

  @spec get_firmware_by_tenant(integer()) :: [Firmware.t()]
  def get_firmware_by_tenant(tenant_id) do
    from(
      f in Firmware,
      where: f.tenant_id == ^tenant_id
    )
    |> Repo.all()
  end

  @spec create_firmware(map) ::
          {:ok, Firmware.t()}
          | {:error, Changeset.t()}
  def create_firmware(firmware) do
    %Firmware{}
    |> Firmware.changeset(firmware)
    |> Repo.insert()
  end

  @spec verify_firmware(String.t()) ::
          {:ok, :signed | :unsigned}
          | {:error, :corrupt_firmware}
  def verify_firmware(filepath) do
    case System.cmd("fwup", ["--verify", "-i", filepath]) do
      {response, 0} ->
        if String.contains?(response, "Pass a public key to verify the signature") do
          {:ok, :signed}
        else
          {:ok, :unsigned}
        end

      {error, 1} ->
        {:error, :corrupt_firmware, error}
    end
  end

  @spec verify_signature(String.t(), [TenantKey.t()]) ::
          {:ok, TenantKey.t()}
          | {:error, :invalid_signature}
  def verify_signature(filepath, keys) do
    keys
    |> Enum.find(fn key ->
      case System.cmd("fwup", ["--verify", "--public-key", key.key, "-i", filepath]) do
        {_, 0} ->
          true

        _ ->
          false
      end
    end)
    |> case do
      %TenantKey{} = key ->
        {:ok, key}

      nil ->
        {:error, :invalid_signature}
    end
  end

  def extract_metadata(filepath) do
    case System.cmd("fwup", ["-m", "-i", filepath]) do
      {metadata, 0} ->
        {:ok, metadata}

      _ ->
        {:error}
    end
  end
end
