import { useQuery } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { Activity, AlertCircle, RefreshCw } from "lucide-react";
import { ActivityCard } from "@/components/activities/activity-card";
import { WeekSummaryPanel } from "@/components/activities/week-summary-panel";
import { getActivities } from "@/lib/api";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/_authenticated/dashboard/")({
	component: DashboardPage,
});

// ---- Skeleton card for loading state ----
function ActivityCardSkeleton() {
	return (
		<div className="rounded-xl border bg-card shadow-sm overflow-hidden animate-pulse">
			<div className="flex items-start gap-3 px-5 pt-5 pb-4">
				<div className="size-9 rounded-lg bg-muted shrink-0" />
				<div className="flex-1 space-y-2">
					<div className="h-4 w-2/5 rounded bg-muted" />
					<div className="h-3 w-1/3 rounded bg-muted" />
				</div>
			</div>
			<div className="mx-5 border-t" />
			<div className="grid grid-cols-4 gap-4 px-5 py-4">
				{(["distance", "pace", "time", "elevation"] as const).map((key) => (
					<div key={key} className="space-y-1.5">
						<div className="h-5 w-16 rounded bg-muted" />
						<div className="h-3 w-12 rounded bg-muted" />
					</div>
				))}
			</div>
			<div className="mx-4 mb-4 h-44 rounded-xl bg-muted" />
		</div>
	);
}

// ---- Empty state ----
function EmptyState() {
	return (
		<div className="flex flex-col items-center justify-center gap-3 rounded-xl border bg-card px-8 py-16 text-center shadow-sm">
			<div className="flex size-14 items-center justify-center rounded-full bg-muted">
				<Activity className="size-7 text-muted-foreground" strokeWidth={1.5} />
			</div>
			<div>
				<p className="font-semibold">No activities yet</p>
				<p className="mt-1 text-sm text-muted-foreground">
					Record your first activity in the Cadent mobile app to see it here.
				</p>
			</div>
		</div>
	);
}

// ---- Error state ----
function ErrorState({ onRetry }: { onRetry: () => void }) {
	return (
		<div className="flex flex-col items-center justify-center gap-3 rounded-xl border border-destructive/20 bg-destructive/5 px-8 py-12 text-center">
			<div className="flex size-12 items-center justify-center rounded-full bg-destructive/10">
				<AlertCircle className="size-6 text-destructive" strokeWidth={1.5} />
			</div>
			<div>
				<p className="font-semibold">Failed to load activities</p>
				<p className="mt-1 text-sm text-muted-foreground">
					Something went wrong fetching your activity data.
				</p>
			</div>
			<button
				type="button"
				onClick={onRetry}
				className={cn(
					"mt-1 flex items-center gap-2 rounded-lg border bg-background px-4 py-2 text-sm font-medium",
					"transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
				)}
			>
				<RefreshCw className="size-3.5" />
				Try again
			</button>
		</div>
	);
}

// ---- Dashboard page ----
function DashboardPage() {
	const { data, isLoading, isError, refetch } = useQuery({
		queryKey: ["activities"],
		queryFn: getActivities,
	});

	const activities = data?.activities ?? [];

	return (
		<div className="px-6 py-8">
			<div className="mx-auto max-w-4xl">
				{/* Page header */}
				<div className="mb-6">
					<h1 className="text-2xl font-bold tracking-tight">Activity Feed</h1>
					<p className="mt-0.5 text-sm text-muted-foreground">
						Your recent training history
					</p>
				</div>

				{/* Two-column layout: stats panel left, feed right */}
				<div className="flex flex-col gap-6 lg:flex-row lg:items-start">
					{/* Week summary — sticky on desktop, stacks above feed on mobile */}
					<aside className="lg:w-56 lg:shrink-0 lg:sticky lg:top-20">
						<WeekSummaryPanel activities={activities} isLoading={isLoading} />
					</aside>

					{/* Activity feed */}
					<div className="flex-1 min-w-0 space-y-5">
						{isLoading && (
							<>
								<ActivityCardSkeleton />
								<ActivityCardSkeleton />
								<ActivityCardSkeleton />
							</>
						)}

						{isError && <ErrorState onRetry={() => refetch()} />}

						{!isLoading && !isError && activities.length === 0 && (
							<EmptyState />
						)}

						{!isLoading &&
							!isError &&
							activities.map((activity) => (
								<ActivityCard key={activity.id} activity={activity} />
							))}
					</div>
				</div>
			</div>
		</div>
	);
}
