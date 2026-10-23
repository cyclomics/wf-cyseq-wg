"""Plot the CNV plot from the CNV analysis done by IchorCNA using plotly
"""

from pathlib import Path
import argparse
from typing import Optional, Tuple

import numpy as np
import pandas as pd
import plotly.graph_objects as go


CNV_COLORS = {
    "HOMD": "#00FF00",
    "HETD": "#006400",
    "NEUT": "#0000FF",
    "GAIN": "#8B0000", 
    "AMP": "#FF0000", 
    "HLAMP": "#FF0000",
    np.nan: "#FFFFFF"
}

class IchorCnaPlotter:
    """Plot the CNV plot from the CNV analysis done by IchorCNA

    Args:
        path: a path that contains the output of IchorCNA. Expects that the following
            files exist: 'tumor_sample.cna.seg', 'tumor_sample.seg.txt', and 'tumor_sample.params.txt'

    Usage:
        from pathlib import Path

        icp = IchorCnaPlotter(path=Path("/my/path/ichor_cna"))
        icp.plot()
    """

    def __init__(self, path: Path):

        if not isinstance(path, Path):
            try:
                path = Path(path)
            except Exception as _:
                raise ValueError(f"path should be a Path, given {type(path)}")

        self.path = path
        self._load()


    def _load(self):

        for required_file in [
            "tumor_sample.cna.seg", 
            "tumor_sample.seg.txt", 
            "tumor_sample.params.txt"
        ]:

            if not (self.path / required_file).exists():
                raise FileNotFoundError(f"Expected file 'tumor_sample.cna.seg' not found in {self.path}")

        self._load_params()
        self._load_cna()
        self._load_segments()

    def _load_params(self):

        self.params_df = pd.read_csv(
            self.path / "tumor_sample.params.txt", 
            header=0, 
            index_col=None, 
            sep="\t", 
            nrows=1,
        )

    def _load_cna(self):

        self.cnv_df = pd.read_csv(
            self.path / "tumor_sample.cna.seg", 
            header=0, 
            index_col=None, 
            sep="\t",
        )

    def _load_segments(self):

        self.seg_df = pd.read_csv(
            self.path / "tumor_sample.seg.txt", 
            header=0, 
            index_col=None, 
            sep="\t",
        )

    def plot(self, output_file: Optional[Path] = None, yrange: Optional[Tuple[float, float]] = None):
        """Plot the CNV profile

        Args:
            output_file: if given, should be a html path to where the plot is saved. If
                not provided, the plot is displayed on the browser/notebook.
            yrange: range for the y-axis. If not given, a range is based on the data
                to ensure all the data is shown.
        """

        chromosomes = self.cnv_df["chr"].unique()

        # calculate correction factor shift based on tumor fraction and ploidy
        # this corrects for the global shift of the CNV profile due to the tumor and 
        # healthy mix
        tumor_fraction = self.params_df["Tumor Fraction"].item()
        phi = self.params_df["Ploidy"].item()
        norm = 1 - tumor_fraction
        ploidy_all = (1 - norm) * phi + norm * 2   
        shift = np.log2(ploidy_all / 2)

        # calculate the coordinates for the x axis for the bins (scatter)
        # scales each chromosome to have the same scale, and adds an offset (i)
        # to plot all the chromosomes in a single axis
        cnv_plot_df = self.cnv_df.copy()
        result = []
        for i, (_, sub) in enumerate(cnv_plot_df.groupby("chr", sort=False)):
            sub["mid"] = (sub["end"] + sub["start"]) / 2
            sub["x_coord"] = (sub["mid"] / sub["end"].max()) + i
            result.append(sub)
        cnv_plot_df = pd.concat(result)
        # add color
        cnv_plot_df["color"] = cnv_plot_df["tumor_sample.Corrected_Call"].apply(CNV_COLORS.get)
        # apply the shift
        cnv_plot_df["y_coord"] = cnv_plot_df["tumor_sample.logR"]
        cnv_plot_df["y_coord"] += shift

        # same as the bins, recalculate the x axis coordinates for the segments
        seg_plot_df = self.seg_df.copy()
        result = []
        for i, (_, sub) in enumerate(seg_plot_df.groupby(["chrom"], sort=False)):
            sub["x_start"] = (sub["start"] / sub["end"].max()) + i
            sub["x_end"] = (sub["end"] / sub["end"].max()) + i
            result.append(sub)
        seg_plot_df = pd.concat(result)
        # apply also the shift
        seg_plot_df["y_coord"] = seg_plot_df["seg.median.logR"]
        seg_plot_df["y_coord"] += shift
        seg_plot_df["n_bins"] = seg_plot_df["num.mark"].astype(int)

        #plotting part

        n_chr = len(chromosomes)
        fig = go.Figure()
        CALL_COL = "tumor_sample.Corrected_Call"
        CN_COL = "tumor_sample.Corrected_Copy_Number"  # only used in hover if present


        cnv_plot_df["coords"] = [f"{c}:{s:,}-{e:,}" for c, s, e in zip(cnv_plot_df["chr"], cnv_plot_df["start"], cnv_plot_df["end"])]
        has_cn = CN_COL in cnv_plot_df.columns

        bin_template = (
            "<b>%{customdata[0]}</b><br>"
            "State: %{customdata[1]}<br>"
            "log2 ratio: %{y:.3f}<br>"
            + ("Copy number: %{customdata[2]}<br>" if has_cn else "")
            + "<extra></extra>"
        )

        for state, sub in cnv_plot_df.groupby(CALL_COL, sort=False, dropna=False):
            cols = [sub["coords"], sub[CALL_COL].astype(str)]
            if has_cn:
                cols.append(sub[CN_COL])
            fig.add_trace(
                go.Scattergl(
                    x=sub["x_coord"],
                    y=sub["y_coord"],
                    mode="markers",
                    name=str(state),
                    marker=dict(color=CNV_COLORS.get(state, "#FFFFFF"), size=4),
                    customdata=np.column_stack(cols),
                    hovertemplate=bin_template,
                )
            )


        extra_cols = [c for c in ("copy.number", "call") if c in seg_plot_df.columns]

        seg_x, seg_y, seg_cd = [], [], []
        for r in seg_plot_df.to_dict("records"):
            n_pts = max(2, int(np.ceil((r["x_end"] - r["x_start"]) / 0.02)) + 1)
            info = [
                f"{r['chrom']}:{int(r['start']):,}-{int(r['end']):,}",
                int(r["n_bins"]),
            ] + [r[c] for c in extra_cols]
            seg_x += np.linspace(r["x_start"], r["x_end"], n_pts).tolist() + [None]
            seg_y += [r["y_coord"]] * n_pts + [None]
            seg_cd += [info] * n_pts + [[None] * len(info)]

        seg_template = (
            "<b>Segment %{customdata[0]}</b><br>"
            "Bins: %{customdata[1]}<br>"
            "Median log2 ratio: %{y:.3f}<br>"
            + "".join(f"{c}: %{{customdata[{j}]}}<br>" for j, c in enumerate(extra_cols, start=2))
            + "<extra></extra>"
        )

        fig.add_trace(
            go.Scattergl(
                x=seg_x,
                y=seg_y,
                mode="lines",
                name="Segments",
                line=dict(color="black", width=2),
                customdata=seg_cd,
                hovertemplate=seg_template,
            )
        )

        # -------------------------------------------------------------- layout
        for i in range(n_chr + 1):
            fig.add_vline(x=i, line=dict(color="grey", dash="dash", width=1))
        fig.add_hline(y=0, line=dict(color="lightgrey", width=1), layer="below")


        if yrange is None:
            yrange = (
                min(-1.8, min(cnv_plot_df["y_coord"])) - 0.2, 
                max(1.8, max(cnv_plot_df["y_coord"])) + 0.2,
            )

        fig.update_layout(
            template="plotly_white",
            height=500,
            hovermode="closest",
            legend_title_text="State",
            margin=dict(l=60, r=20, t=30, b=40),
            xaxis=dict(
                range=[-0.5, n_chr + 0.5],
                tickmode="array",
                tickvals=np.arange(0.5, n_chr + 0.5, 1),
                ticktext=[str(c) for c in chromosomes],
                showgrid=False,
            ),
            yaxis=dict(
                title="Copy Number (log2 ratio)",
                range=yrange,
                showgrid=False,
                zeroline=False,
            ),
        )
        fig.update_layout(showlegend=False)
        fig.update_layout(title=f"Tumor Fraction: {tumor_fraction}, Ploidy: {phi:.2f}")
        fig.show()

        if output_file is not None:
            fig.write_html(output_file)
        else:
            fig.show()
            return fig


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input-path", type=str, required=True)
    parser.add_argument("-o", "--output-html", type=str, required=True)
    args = parser.parse_args()


    obj = IchorCnaPlotter(Path(args.input_path))
    obj.plot(Path(args.output_html))