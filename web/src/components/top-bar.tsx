import { DropdownMenu } from "radix-ui";
import {
	ChevronDown,
	Settings,
	LogOut,
	Activity,
	CalendarDays,
	ClipboardList,
} from "lucide-react";
import { Link, useRouter } from "@tanstack/react-router";
import { useAuth } from "@/contexts/auth-context";
import { cn } from "@/lib/utils";
import { UserThumbnail } from "@/components/user/user-thumbnail";

function NavDropdown({
	label,
	children,
}: {
	label: string;
	children: React.ReactNode;
}) {
	return (
		<DropdownMenu.Root>
			<DropdownMenu.Trigger
				className={cn(
					"group flex items-center gap-1 rounded-md px-3 py-2 text-sm font-medium",
					"text-foreground/80 transition-colors hover:text-foreground",
					"data-[state=open]:text-foreground",
					"outline-none focus-visible:ring-2 focus-visible:ring-ring",
					"cursor-pointer select-none",
				)}
			>
				{label}
				<ChevronDown
					className="size-3.5 text-muted-foreground transition-transform duration-200 group-data-[state=open]:rotate-180"
					strokeWidth={2.5}
				/>
			</DropdownMenu.Trigger>

			<DropdownMenu.Portal>
				<DropdownMenu.Content
					sideOffset={8}
					align="start"
					className={cn(
						"z-50 min-w-44 overflow-hidden rounded-lg border bg-popover p-1 shadow-md",
						"data-[state=open]:animate-in data-[state=closed]:animate-out",
						"data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
						"data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
						"data-[side=bottom]:slide-in-from-top-2",
					)}
				>
					{children}
				</DropdownMenu.Content>
			</DropdownMenu.Portal>
		</DropdownMenu.Root>
	);
}

function DropdownLink({
	to,
	icon: Icon,
	children,
}: {
	to: string;
	icon?: React.ElementType;
	children: React.ReactNode;
}) {
	return (
		<DropdownMenu.Item asChild>
			<Link
				to={to}
				className={cn(
					"flex cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-sm",
					"text-foreground/80 outline-none transition-colors",
					"hover:bg-accent hover:text-accent-foreground",
					"focus:bg-accent focus:text-accent-foreground",
					"data-disabled:pointer-events-none data-disabled:opacity-50",
				)}
			>
				{Icon && <Icon className="size-4 shrink-0 text-muted-foreground" />}
				{children}
			</Link>
		</DropdownMenu.Item>
	);
}

export function TopBar() {
	const auth = useAuth();
	const router = useRouter();

	async function handleLogout() {
		await auth.logout();
		router.navigate({ to: "/login", search: { redirect: undefined } });
	}

	return (
		<header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur-sm">
			<div className="mx-auto flex h-16 w-full max-w-screen-2xl items-center gap-2 px-6">
				{/* Logo */}
				<Link to="/dashboard" className="shrink-0 mr-4">
					<img
						src="/logofull.png"
						alt="Cadent"
						className="h-10 w-auto object-contain"
					/>
				</Link>

				{/* Primary nav */}
				<nav className="flex items-center gap-0.5">
					<NavDropdown label="Dashboard">
						<DropdownLink to="/dashboard" icon={Activity}>
							Activity Feed
						</DropdownLink>
					</NavDropdown>

					<NavDropdown label="Training">
						<DropdownLink to="/dashboard" icon={CalendarDays}>
							Training Calendar
						</DropdownLink>
						<DropdownLink to="/training-plans" icon={ClipboardList}>
							Training Plans
						</DropdownLink>
					</NavDropdown>
				</nav>

				{/* Push profile to the right */}
				<div className="flex-1" />

				{/* User profile dropdown */}
				<DropdownMenu.Root>
					<DropdownMenu.Trigger
						className={cn(
							"flex size-8 items-center justify-center rounded-full",
							"bg-primary text-primary-foreground text-xs font-semibold",
							"ring-2 ring-transparent transition-all",
							"hover:ring-ring/40 data-[state=open]:ring-ring/60",
							"outline-none cursor-pointer select-none",
						)}
						aria-label="User menu"
					>
						<UserThumbnail user={auth.user} />
					</DropdownMenu.Trigger>

					<DropdownMenu.Portal>
						<DropdownMenu.Content
							sideOffset={8}
							align="end"
							className={cn(
								"z-50 min-w-44 overflow-hidden rounded-lg border bg-popover p-1 shadow-md",
								"data-[state=open]:animate-in data-[state=closed]:animate-out",
								"data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
								"data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
								"data-[side=bottom]:slide-in-from-top-2",
							)}
						>
							{auth.user && (
								<>
									<div className="px-3 py-2 border-b mb-1">
										<p className="text-sm font-medium leading-tight truncate">
											{auth.user.name || auth.user.email}
										</p>
										{auth.user.name && (
											<p className="text-xs text-muted-foreground truncate">
												{auth.user.email}
											</p>
										)}
									</div>
								</>
							)}

							<DropdownMenu.Item
								className={cn(
									"flex cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-sm",
									"text-foreground/80 outline-none transition-colors",
									"hover:bg-accent hover:text-accent-foreground",
									"focus:bg-accent focus:text-accent-foreground",
								)}
							>
								<Settings className="size-4 shrink-0 text-muted-foreground" />
								Settings
							</DropdownMenu.Item>

							<DropdownMenu.Separator className="mx-1 my-1 h-px bg-border" />

							<DropdownMenu.Item
								onSelect={handleLogout}
								className={cn(
									"flex cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-sm",
									"text-destructive outline-none transition-colors",
									"hover:bg-destructive/10 hover:text-destructive",
									"focus:bg-destructive/10 focus:text-destructive",
								)}
							>
								<LogOut className="size-4 shrink-0" />
								Log out
							</DropdownMenu.Item>
						</DropdownMenu.Content>
					</DropdownMenu.Portal>
				</DropdownMenu.Root>
			</div>
		</header>
	);
}
