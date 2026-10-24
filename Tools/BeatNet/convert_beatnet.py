#!/usr/bin/env python3
"""Convert BeatNet's generic CRNN weights to a fixed-window Core ML model."""

from pathlib import Path
import argparse

import coremltools as ct
import torch
from torch import nn
from torch.nn import functional as functional


FRAME_COUNT = 1_600
FEATURE_COUNT = 272
HIDDEN_COUNT = 150


class BeatDownbeatActivation(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.conv1 = nn.Conv1d(1, 2, 10)
        self.linear0 = nn.Linear(262, HIDDEN_COUNT)
        self.lstm = nn.LSTM(
            input_size=HIDDEN_COUNT,
            hidden_size=HIDDEN_COUNT,
            num_layers=2,
            batch_first=True,
            bidirectional=False,
        )
        self.linear = nn.Linear(HIDDEN_COUNT, 3)

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        batch_size = features.shape[0]
        frame_count = features.shape[1]
        hidden = features.reshape(-1, FEATURE_COUNT)
        hidden = hidden.unsqueeze(1)
        hidden = functional.max_pool1d(
            functional.relu(self.conv1(hidden)),
            2,
        )
        hidden = hidden.reshape(-1, 262)
        hidden = self.linear0(hidden)
        hidden = hidden.reshape(batch_size, frame_count, HIDDEN_COUNT)
        hidden = self.lstm(hidden)[0]
        logits = self.linear(hidden)
        probabilities = torch.softmax(logits, dim=-1)
        return probabilities[:, :, :2]


def convert(weights_path: Path, output_path: Path) -> None:
    network = BeatDownbeatActivation()
    state = torch.load(weights_path, map_location="cpu", weights_only=True)
    network.load_state_dict(state, strict=True)
    network.eval()

    example = torch.zeros(
        (1, FRAME_COUNT, FEATURE_COUNT),
        dtype=torch.float32,
    )
    traced = torch.jit.trace(network, example)
    model = ct.convert(
        traced,
        convert_to="mlprogram",
        inputs=[
            ct.TensorType(
                name="features",
                shape=example.shape,
                dtype=float,
            )
        ],
        outputs=[ct.TensorType(name="activations")],
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS18,
    )
    model.author = "Mojtaba Heydari; Core ML conversion by MeloX"
    model.license = "CC BY 4.0"
    model.short_description = (
        "BeatNet generic beat/downbeat activation model for 32-second windows."
    )
    model.input_description["features"] = (
        "1 x 1600 x 272 log-filtered spectrogram and positive-difference features."
    )
    model.output_description["activations"] = (
        "1 x 1600 x 2 probabilities ordered as beat and downbeat."
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    model.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("weights", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    convert(args.weights, args.output)


if __name__ == "__main__":
    main()
